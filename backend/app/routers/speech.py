"""Speech & Pronunciation component: proxies scoring to the speech inference service.

The response body is the speech service's /assess contract, passed through unchanged (see
docs/api-contract.md). Stage 1 is stateless: the app records the completed word through the
shared offline queue (POST /activity-results). phoneme_progress persistence arrives in Stage 5.
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
    try:
        resp = client.post(
            "/assess",
            files={"audio": (audio.filename or "audio.wav", raw, "audio/wav")},
            data={"word_id": word_id, "language": language},
        )
    except httpx.HTTPError as exc:
        raise HTTPException(503, "Speech service is unavailable.") from exc

    if 400 <= resp.status_code < 500 or resp.status_code == 503:
        # Bad input (unknown word, silent/too-long audio, ...) or no reference recordings for the
        # word yet (503): pass the reason through.
        raise HTTPException(resp.status_code, resp.json().get("detail", "Bad request."))
    if resp.status_code != 200:
        raise HTTPException(502, "Speech service error.")
    return resp.json()
