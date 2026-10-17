"""Speech & Pronunciation component: proxies scoring to the speech inference service.

The response body is the speech service's /assess contract, passed through unchanged (see
docs/api-contract.md). Stage 1 is stateless: the app records the completed word through the
shared offline queue (POST /activity-results). phoneme_progress persistence arrives in Stage 5.

POST /speech/assess-unit scores one unit or a blend (remediation loop) and, for single units,
records the attempt in phoneme_progress. GET /speech/progress/{child_id} lists that record (lowest
mastery first). GET /speech/words and GET /speech/listen/{word_id} pass through word info and ADULT
model audio.

POST /speech/references is a developer tool for adding ADULT reference recordings. The speech
service rejects it (404) unless started with SPEECH_ALLOW_REFERENCE_UPLOAD=1.
"""

import uuid
from collections.abc import Generator
from typing import Any, Literal

import logging

import httpx
from fastapi import APIRouter, Depends, File, Form, HTTPException, Response, UploadFile
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.db import get_db
from app.schemas.speech import PhonemeProgressRead
from app.services import speech_progress_service

log = logging.getLogger(__name__)

router = APIRouter(prefix="/speech", tags=["speech"])

MAX_UPLOAD_BYTES = 2_000_000


def get_speech_client() -> Generator[httpx.Client, None, None]:
    settings = get_settings()
    with httpx.Client(base_url=settings.speech_service_url, timeout=settings.speech_service_timeout_s) as client:
        yield client


@router.post("/assess")
def assess(
    audio: UploadFile = File(...),
    word_id: str = Form(...),
    language: Literal["si", "en"] = Form(...),
    child_id: uuid.UUID = Form(...),
    client: httpx.Client = Depends(get_speech_client),
) -> dict[str, Any]:
    raw = audio.file.read(MAX_UPLOAD_BYTES + 1)
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "Audio file is too large.")
    return _forward(client, "/assess", audio, raw, {"word_id": word_id, "language": language})


@router.post("/assess-unit")
def assess_unit(
    audio: UploadFile = File(...),
    word_id: str = Form(...),
    language: Literal["si", "en"] = Form(...),
    start_unit: int = Form(...),
    end_unit: int = Form(...),
    child_id: uuid.UUID = Form(...),
    client: httpx.Client = Depends(get_speech_client),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    raw = audio.file.read(MAX_UPLOAD_BYTES + 1)
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "Audio file is too large.")
    form = {"word_id": word_id, "language": language, "start_unit": start_unit, "end_unit": end_unit}
    result = _forward(client, "/assess_unit", audio, raw, form)
    if start_unit == end_unit:  # blends are practice steps, not units: only units are recorded
        try:
            speech_progress_service.record_unit_attempt(
                db, child_id, language, result["label"], result["decision"] == "accepted", result["score"]
            )
        except SQLAlchemyError:
            # e.g. the child profile has not synced to the backend yet: the score still counts.
            db.rollback()
            log.warning("phoneme_progress not recorded for child %s", child_id, exc_info=True)
    return result


@router.get("/progress/{child_id}", response_model=list[PhonemeProgressRead])
def get_progress(child_id: uuid.UUID, db: Session = Depends(get_db)) -> list[PhonemeProgressRead]:
    return [PhonemeProgressRead.model_validate(r) for r in speech_progress_service.list_progress(db, child_id)]


@router.get("/words")
def words(client: httpx.Client = Depends(get_speech_client)) -> list[dict[str, Any]]:
    resp = _get(client, "/words")
    return resp.json()


@router.get("/listen/{word_id}")
def listen(
    word_id: str,
    start_unit: int | None = None,
    end_unit: int | None = None,
    client: httpx.Client = Depends(get_speech_client),
) -> Response:
    params = {} if start_unit is None else {"start_unit": start_unit, "end_unit": end_unit}
    resp = _get(client, f"/listen/{word_id}", params)
    return Response(resp.content, media_type="audio/wav", headers={"X-Ref-Id": resp.headers.get("x-ref-id", "")})


def _get(client: httpx.Client, path: str, params: dict | None = None) -> httpx.Response:
    try:
        resp = client.get(path, params=params)
    except httpx.HTTPError as exc:
        raise HTTPException(503, "Speech service is unavailable.") from exc
    _raise_for_service_error(resp)
    return resp


@router.post("/references")
def add_reference(
    audio: UploadFile = File(...),
    word_id: str = Form(...),
    language: Literal["si", "en"] = Form(...),
    speaker_id: str = Form(...),
    age_group: str = Form(...),
    accent: str = Form("unknown"),
    client: httpx.Client = Depends(get_speech_client),
) -> dict[str, Any]:
    raw = audio.file.read(MAX_UPLOAD_BYTES + 1)
    if len(raw) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "Audio file is too large.")
    form = {
        "word_id": word_id,
        "language": language,
        "speaker_id": speaker_id,
        "age_group": age_group,
        "accent": accent,
    }
    return _forward(client, "/references", audio, raw, form)


def _forward(client: httpx.Client, path: str, audio: UploadFile, raw: bytes, form: dict) -> dict[str, Any]:
    try:
        resp = client.post(path, files={"audio": (audio.filename or "audio.wav", raw, "audio/wav")}, data=form)
    except httpx.HTTPError as exc:
        raise HTTPException(503, "Speech service is unavailable.") from exc

    _raise_for_service_error(resp)
    return resp.json()


def _raise_for_service_error(resp: httpx.Response) -> None:
    if 400 <= resp.status_code < 500 or resp.status_code == 503:
        # Bad input (unknown word, silent/too-long audio, ...) or no reference recordings for the
        # word yet (503): pass the reason through.
        try:
            detail = resp.json().get("detail", "Bad request.")
        except ValueError:
            detail = "Bad request."
        raise HTTPException(resp.status_code, detail)
    if resp.status_code != 200:
        raise HTTPException(502, "Speech service error.")
