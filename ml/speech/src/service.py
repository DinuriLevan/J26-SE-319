"""Speech assessment inference service.

    POST /assess      multipart: audio (WAV), word_id, language (si|en)
    GET  /health
    POST /assess_unit multipart: audio, word_id, language, start_unit, end_unit (a unit or a blend)
    GET  /listen/{word_id}?start_unit=&end_unit=  adult model audio (WAV) for the LISTEN step
    GET  /words       units per word and which have adult model audio
    POST /references  developer tool, OFF unless SPEECH_ALLOW_REFERENCE_UPLOAD=1: add an ADULT
                      reference recording (audio, word_id, language, speaker_id, age_group, accent)

Run (from ml/speech):
    uvicorn src.service:app --port 8001
Environment:
    SPEECH_EMBEDDER   xlsr (default) | spectral (model-free stand-in, dev/tests only)
    SPEECH_SETTINGS   path to settings.yaml (default config/settings.yaml)
    SPEECH_ALLOW_REFERENCE_UPLOAD  1 to enable POST /references (dev only; adults only)

scoring.mode = "bank" (default): score against every reference of the word (mean of the k nearest)
and accept within the range learned from the bank itself (src/threshold.py); words with fewer than
min_refs references use the config fallback (threshold_source = "fallback").
scoring.mode = "single": Stage 1 baseline, one adult reference + fallback threshold.
When an attempt is not accepted, `segments` locates the likely problem unit(s) (src/localise.py).
"""

from __future__ import annotations

import io
import json
import logging
import os
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Literal

import numpy as np
import soundfile as sf
from fastapi import FastAPI, File, Form, HTTPException, Query, Response, UploadFile
from pydantic import BaseModel

from src.audio import AudioValidationError, load_audio
from src.bank import BankError, ReferenceBank
from src.dtw_fast import dtw as fast_dtw
from src.embed import Embedder, make_embedder
from src.localise import localise_attempt
from src.scoring import score_against_references
from src.settings import DEFAULT_SETTINGS, load_settings
from src.threshold import AcceptanceRange, acceptance_range
from src.units import SpanBank

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


class UnitAssessResponse(BaseModel):
    word_id: str
    start_unit: int
    end_unit: int
    label: str
    decision: Literal["accepted", "needs_remediation"]
    score: float
    threshold: float
    threshold_source: Literal["bank", "fallback"]
    latency_ms: Latency


class WordInfo(BaseModel):
    word_id: str
    text: str
    language: str
    units: list[str]
    listen_units: list[int]
    has_word_audio: bool


class ReferenceResponse(BaseModel):
    word_id: str
    ref_id: str
    n_refs: int
    n_speakers: int
    threshold: float
    threshold_source: Literal["bank", "fallback"]


def create_app(
    settings: dict,
    embedder: Embedder,
    bank: ReferenceBank,
    allow_reference_upload: bool = False,
) -> FastAPI:
    bank.check_embedder(embedder.name)
    sc = settings["scoring"]
    mode = sc.get("mode", "bank")
    ranges: dict[str, AcceptanceRange] = {}
    spans = SpanBank(bank, embedder, settings)

    def word_range(word_id: str, refs: list[dict]) -> AcceptanceRange:
        # Computed once per word; POST /references drops the cached range when it adds a reference.
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
            # Pre-compute unit and blend span references, so the first remediation attempt for a
            # unit is not slowed down by cutting and embedding every reference (~2 s per span).
            t = time.perf_counter()
            n_spans = 0
            for word_id in bank.words:
                n = len(spans.units(word_id))
                for a in range(n):
                    for b in (a, a + 1):
                        if b < n and spans.span_refs(word_id, a, b):
                            spans.span_range(word_id, a, b)
                            n_spans += 1
            log.info("warmed %d unit/blend spans in %.1f s", n_spans, time.perf_counter() - t)
        yield

    app = FastAPI(title="AkuRin speech assessment", version="0.1.0", lifespan=lifespan)
    audio_cfg = settings["audio"]

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "embedder": embedder.name}

    def read_word_audio(audio: UploadFile, word_id: str, language: str) -> np.ndarray:
        """Validate the word and the upload; return trimmed 16 kHz mono audio (4xx on bad input)."""
        word = bank.words.get(word_id)
        if word is None:
            raise HTTPException(404, f"Unknown word_id {word_id!r}.")
        if word["language"] != language:
            raise HTTPException(422, f"{word_id} is a {word['language']!r} word, not {language!r}.")
        raw = audio.file.read(settings["service"]["max_upload_bytes"] + 1)
        if len(raw) > settings["service"]["max_upload_bytes"]:
            raise HTTPException(413, "Audio file is too large.")
        try:
            return load_audio(
                raw,
                target_sr=audio_cfg["sample_rate"],
                max_duration_s=audio_cfg["max_duration_s"],
                trim_top_db=audio_cfg["trim_top_db"],
            )
        except AudioValidationError as exc:
            raise HTTPException(400, str(exc)) from exc

    @app.post("/assess", response_model=AssessResponse)
    def assess(
        audio: UploadFile = File(...),
        word_id: str = Form(...),
        language: Literal["si", "en"] = Form(...),
    ) -> AssessResponse:
        t0 = time.perf_counter()
        wav = read_word_audio(audio, word_id, language)
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
        accepted = score <= threshold
        segments = []
        if not accepted and mode != "single":
            by_id = {r["variant_id"]: r for r in refs}
            best = next((x for x in results if by_id[x["variant_id"]].get("units")), None)
            if best is not None:
                segments = localise_attempt(
                    child_emb, by_id[best["variant_id"]], best["path"], settings
                )
        t3 = time.perf_counter()

        ms = lambda a, b: round((b - a) * 1000, 1)  # noqa: E731
        latency = Latency(load=ms(t0, t1), embed=ms(t1, t2), dtw=ms(t2, t3), total=ms(t0, t3))
        log.info("assess %s score=%.3f latency=%s", word_id, score, latency.model_dump())
        return AssessResponse(
            word_id=word_id,
            decision="accepted" if accepted else "needs_remediation",
            score=round(score, 4),
            threshold=round(threshold, 4),
            threshold_source=source,
            nearest_variant=results[0]["variant_id"],
            segments=segments,
            latency_ms=latency,
        )

    def span_or_422(word_id: str, start_unit: int, end_unit: int) -> list[str]:
        if word_id not in bank.words:
            raise HTTPException(404, f"Unknown word_id {word_id!r}.")
        units = spans.units(word_id)
        if not 0 <= start_unit <= end_unit < len(units):
            raise HTTPException(422, f"Unit span {start_unit}-{end_unit} is outside {word_id}.")
        return units

    @app.get("/words", response_model=list[WordInfo])
    def words() -> list[WordInfo]:
        return [
            WordInfo(
                word_id=w,
                text=row["text_si"] or row["text_en"],
                language=row["language"],
                units=spans.units(w),
                listen_units=spans.listen_units(w),
                has_word_audio=spans.has_word_audio(w),
            )
            for w, row in bank.words.items()
        ]

    @app.post("/assess_unit", response_model=UnitAssessResponse)
    def assess_unit(
        audio: UploadFile = File(...),
        word_id: str = Form(...),
        language: Literal["si", "en"] = Form(...),
        start_unit: int = Form(...),
        end_unit: int = Form(...),
    ) -> UnitAssessResponse:
        t0 = time.perf_counter()
        units = span_or_422(word_id, start_unit, end_unit)
        wav = read_word_audio(audio, word_id, language)
        t1 = time.perf_counter()
        emb = embedder.embed(wav)
        t2 = time.perf_counter()
        refs = spans.span_refs(word_id, start_unit, end_unit)
        if not refs:
            raise HTTPException(503, f"No unit references for {word_id} yet.")
        score, _ = score_against_references(emb, refs, k=sc["k_nearest"], dtw_fn=fast_dtw)
        rng = spans.span_range(word_id, start_unit, end_unit)
        t3 = time.perf_counter()
        ms = lambda a, b: round((b - a) * 1000, 1)  # noqa: E731
        return UnitAssessResponse(
            word_id=word_id,
            start_unit=start_unit,
            end_unit=end_unit,
            label="".join(units[start_unit : end_unit + 1]),
            decision="accepted" if score <= rng.threshold else "needs_remediation",
            score=round(score, 4),
            threshold=round(rng.threshold, 4),
            threshold_source=rng.source,
            latency_ms=Latency(load=ms(t0, t1), embed=ms(t1, t2), dtw=ms(t2, t3), total=ms(t0, t3)),
        )

    @app.get("/listen/{word_id}")
    def listen(
        word_id: str,
        start_unit: int | None = Query(None),
        end_unit: int | None = Query(None),
    ) -> Response:
        """ADULT model audio only: children's recordings are never played back."""
        if (start_unit is None) != (end_unit is None):
            raise HTTPException(422, "Give both start_unit and end_unit, or neither.")
        if start_unit is None:
            if word_id not in bank.words:
                raise HTTPException(404, f"Unknown word_id {word_id!r}.")
        else:
            span_or_422(word_id, start_unit, end_unit)
        clip = spans.listen_clip(word_id, start_unit, end_unit)
        if clip is None:
            raise HTTPException(404, f"No adult model audio for {word_id} yet.")
        ref_id, wav = clip
        buf = io.BytesIO()
        sf.write(buf, wav, settings["audio"]["sample_rate"], format="WAV", subtype="PCM_16")
        return Response(buf.getvalue(), media_type="audio/wav", headers={"X-Ref-Id": ref_id})

    if allow_reference_upload:

        @app.post("/references", response_model=ReferenceResponse)
        def add_reference(
            audio: UploadFile = File(...),
            word_id: str = Form(...),
            language: Literal["si", "en"] = Form(...),
            speaker_id: str = Form(..., pattern=r"^[a-z0-9_]{1,32}$"),
            age_group: str = Form(...),
            accent: str = Form("unknown", max_length=40),
        ) -> ReferenceResponse:
            """Developer tool: add an ADULT reference recording to the bank (off by default).
            Children's voices are never stored through this endpoint."""
            if age_group != "adult":
                raise HTTPException(422, "Only adult reference recordings can be added here.")
            wav = read_word_audio(audio, word_id, language)
            ref_dir = bank.reference_dir / word_id
            emb_dir = bank.embeddings_dir / word_id
            ref_dir.mkdir(parents=True, exist_ok=True)
            emb_dir.mkdir(parents=True, exist_ok=True)
            n = len(list(ref_dir.glob(f"{speaker_id}_p*.json"))) + 1
            ref_id = f"{speaker_id}_p{n:02d}"
            sf.write(ref_dir / f"{ref_id}.wav", wav, audio_cfg["sample_rate"])
            np.save(emb_dir / f"{ref_id}.npy", embedder.embed(wav))
            meta = {
                "speaker_id": speaker_id,
                "age_group": "adult",
                "accent": accent,
                "source": "app_recording",
                "recorded_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "units": [],
            }
            (ref_dir / f"{ref_id}.json").write_text(
                json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
            )
            ranges.pop(word_id, None)  # the bank changed: relearn this word's range
            spans.invalidate(word_id)
            refs = bank.reference_set(word_id)
            r = word_range(word_id, refs)
            log.info(
                "reference %s/%s added: %d refs, threshold %.3f (%s)",
                word_id,
                ref_id,
                r.n_refs,
                r.threshold,
                r.source,
            )
            return ReferenceResponse(
                word_id=word_id,
                ref_id=ref_id,
                n_refs=r.n_refs,
                n_speakers=len({x["speaker"] for x in refs}),
                threshold=round(r.threshold, 4),
                threshold_source=r.source,
            )

    return app


def _app_from_env() -> FastAPI:
    logging.basicConfig(level=logging.INFO)
    settings = load_settings(os.environ.get("SPEECH_SETTINGS", DEFAULT_SETTINGS))
    embedder = make_embedder(os.environ.get("SPEECH_EMBEDDER", "xlsr"), settings)
    allow = os.environ.get("SPEECH_ALLOW_REFERENCE_UPLOAD") == "1"
    if allow:
        log.warning("POST /references is ENABLED (developer tool, adult recordings only)")
    return create_app(settings, embedder, ReferenceBank.from_settings(settings), allow)


def __getattr__(name: str):
    # Lazy so that importing src.service in tests does not load the model.
    if name == "app":
        return _app_from_env()
    raise AttributeError(name)
