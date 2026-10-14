"""Speech assessment inference service.

    POST /assess   multipart: audio (WAV), word_id, language (si|en)
    GET  /health

Run (from ml/speech):
    uvicorn src.service:app --port 8001
Environment:
    SPEECH_EMBEDDER   xlsr (default) | spectral (model-free stand-in, dev/tests only)
    SPEECH_SETTINGS   path to settings.yaml (default config/settings.yaml)

Stage 1: scores against ONE adult reference with the fallback threshold from config.
The multi-reference bank, learned range and segments come in Stages 3-4.
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
from src.embed import Embedder, make_embedder
from src.scoring import score_against_references
from src.settings import DEFAULT_SETTINGS, load_settings

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

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        t = time.perf_counter()
        embedder.embed(np.random.default_rng(0).normal(scale=0.1, size=16000).astype(np.float32))
        log.info("warm-up inference %.0f ms (%s)", (time.perf_counter() - t) * 1000, embedder.name)
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

        try:
            ref = bank.baseline_reference(word_id, settings["baseline"]["reference_speaker"])
        except BankError as exc:
            raise HTTPException(503, str(exc)) from exc
        refs = [{"emb": ref["emb"], "age_group": ref["age_group"], "variant_id": ref["speaker_id"]}]
        score, results = score_against_references(child_emb, refs, k=1)
        t3 = time.perf_counter()

        threshold = float(settings["scoring"]["fallback_threshold"])
        ms = lambda a, b: round((b - a) * 1000, 1)  # noqa: E731
        latency = Latency(load=ms(t0, t1), embed=ms(t1, t2), dtw=ms(t2, t3), total=ms(t0, t3))
        log.info("assess %s score=%.3f latency=%s", word_id, score, latency.model_dump())
        return AssessResponse(
            word_id=word_id,
            decision="accepted" if score <= threshold else "needs_remediation",
            score=round(score, 4),
            threshold=threshold,
            threshold_source="fallback",
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
