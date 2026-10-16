"""Speech assessment inference service.

    POST /assess   multipart: audio (WAV), word_id, language (si|en)
    GET  /health

Run (from ml/speech):
    uvicorn src.service:app --port 8001
Environment:
    SPEECH_EMBEDDER   xlsr (default) | spectral (model-free stand-in, dev/tests only)
    SPEECH_SETTINGS   path to settings.yaml (default config/settings.yaml)

scoring.mode = "bank" (default): score against every reference of the word (mean of the k nearest)
and accept within the range learned from the bank itself (src/threshold.py); words with fewer than
min_refs references use the config fallback (threshold_source = "fallback").
scoring.mode = "single": Stage 1 baseline, one adult reference + fallback threshold.
Segments (localisation) come in Stage 4.
"""

from __future__ import annotations

import logging
import os
import time
from contextlib import asynccontextmanager
from typing import Literal

import numpy as np
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from pydantic import BaseModel

from src.audio import AudioValidationError, load_audio
from src.bank import BankError, ReferenceBank
from src.dtw_fast import dtw as fast_dtw
from src.embed import Embedder, make_embedder
from src.scoring import score_against_references
from src.settings import DEFAULT_SETTINGS, load_settings
from src.threshold import AcceptanceRange, acceptance_range

log = logging.getLogger("speech.service")


class Segment(BaseModel):
    label: str
    start_s: float
    end_s: float
    status: Literal["ok", "flagged"]
    cost: float
    error_type: Literal["substitution", "omission", "insertion", "distortion"] | None = None


class Latency(BaseModel):
    load: float
    embed: float
    dtw: float
    total: float


class AssessResponse(BaseModel):
    word_id: str
    decision: Literal["accepted", "needs_remediation"]
    score: float
    threshold: float
    threshold_source: Literal["bank", "fallback"]
    nearest_variant: str
    segments: list[Segment]
    latency_ms: Latency


def create_app(settings: dict, embedder: Embedder, bank: ReferenceBank) -> FastAPI:
    bank.check_embedder(embedder.name)
    sc = settings["scoring"]
    mode = sc.get("mode", "bank")
    ranges: dict[str, AcceptanceRange] = {}

    def word_range(word_id: str, refs: list[dict]) -> AcceptanceRange:
        # The bank is fixed while the service runs, so each word's range is computed once.
        if word_id not in ranges:
            ranges[word_id] = acceptance_range(
                refs,
                k=sc["k_nearest"],
                n_std=sc["n_std"],
                min_refs=sc["min_refs_for_bank_threshold"],
                fallback=sc["fallback_threshold"],
                dtw_fn=fast_dtw,
                loo_unit=sc.get("loo_unit", "token"),
            )
        return ranges[word_id]

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        t = time.perf_counter()
        embedder.embed(np.random.default_rng(0).normal(scale=0.1, size=16000).astype(np.float32))
        log.info("warm-up inference %.0f ms (%s)", (time.perf_counter() - t) * 1000, embedder.name)
        if mode == "bank":
            for word_id in bank.words:
                refs = bank.reference_set(word_id)
                if refs:
                    r = word_range(word_id, refs)
                    log.info(
                        "%s: %d refs, threshold %.3f (%s)", word_id, r.n_refs, r.threshold, r.source
                    )
        yield

    app = FastAPI(title="AkuRin speech assessment", version="0.1.0", lifespan=lifespan)
    audio_cfg = settings["audio"]

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "embedder": embedder.name}

    @app.post("/assess", response_model=AssessResponse)
    def assess(
        audio: UploadFile = File(...),
        word_id: str = Form(...),
        language: Literal["si", "en"] = Form(...),
    ) -> AssessResponse:
        t0 = time.perf_counter()
        word = bank.words.get(word_id)
        if word is None:
            raise HTTPException(404, f"Unknown word_id {word_id!r}.")
        if word["language"] != language:
            raise HTTPException(422, f"{word_id} is a {word['language']!r} word, not {language!r}.")

        raw = audio.file.read(settings["service"]["max_upload_bytes"] + 1)
        if len(raw) > settings["service"]["max_upload_bytes"]:
            raise HTTPException(413, "Audio file is too large.")
        try:
            wav = load_audio(
                raw,
                target_sr=audio_cfg["sample_rate"],
                max_duration_s=audio_cfg["max_duration_s"],
                trim_top_db=audio_cfg["trim_top_db"],
            )
        except AudioValidationError as exc:
            raise HTTPException(400, str(exc)) from exc
        t1 = time.perf_counter()

        child_emb = embedder.embed(wav)
        t2 = time.perf_counter()

        if mode == "single":
            try:
                ref = bank.baseline_reference(word_id, settings["baseline"]["reference_speaker"])
            except BankError as exc:
                raise HTTPException(503, str(exc)) from exc
            refs = [{"emb": ref["emb"], "age_group": ref["age_group"], "variant_id": ref["ref_id"]}]
            score, results = score_against_references(child_emb, refs, k=1, dtw_fn=fast_dtw)
            threshold, source = float(sc["fallback_threshold"]), "fallback"
        else:
            refs = bank.reference_set(word_id)
            if not refs:
                raise HTTPException(503, f"No reference recordings for {word_id} yet.")
            score, results = score_against_references(
                child_emb, refs, k=sc["k_nearest"], dtw_fn=fast_dtw
            )
            rng = word_range(word_id, refs)
            threshold, source = rng.threshold, rng.source
        t3 = time.perf_counter()

        ms = lambda a, b: round((b - a) * 1000, 1)  # noqa: E731
        latency = Latency(load=ms(t0, t1), embed=ms(t1, t2), dtw=ms(t2, t3), total=ms(t0, t3))
        log.info("assess %s score=%.3f latency=%s", word_id, score, latency.model_dump())
        return AssessResponse(
            word_id=word_id,
            decision="accepted" if score <= threshold else "needs_remediation",
            score=round(score, 4),
            threshold=round(threshold, 4),
            threshold_source=source,
            nearest_variant=results[0]["variant_id"],
            segments=[],
            latency_ms=latency,
        )

    return app


def _app_from_env() -> FastAPI:
    logging.basicConfig(level=logging.INFO)
    settings = load_settings(os.environ.get("SPEECH_SETTINGS", DEFAULT_SETTINGS))
    embedder = make_embedder(os.environ.get("SPEECH_EMBEDDER", "xlsr"), settings)
    return create_app(settings, embedder, ReferenceBank.from_settings(settings))


def __getattr__(name: str):
    # Lazy so that importing src.service in tests does not load the model.
    if name == "app":
        return _app_from_env()
    raise AttributeError(name)
