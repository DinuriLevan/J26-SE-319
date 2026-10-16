"""Speech & Pronunciation component: proxies scoring to the speech inference service.

The response body is the speech service's /assess contract, passed through unchanged (see
docs/api-contract.md). Stage 1 is stateless: the app records the completed word through the
shared offline queue (POST /activity-results). phoneme_progress persistence arrives in Stage 5.

POST /speech/references is a developer tool for adding ADULT reference recordings. The speech
service rejects it (404) unless started with SPEECH_ALLOW_REFERENCE_UPLOAD=1.
"""

import uuid
from collections.abc import Generator
from typing import Any, Literal

import httpx
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.core.config import get_settings

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
    return resp.json()
