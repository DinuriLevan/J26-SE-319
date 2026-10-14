"""Speech proxy router tests. The speech service is faked with httpx.MockTransport (no network, no DB)."""

import uuid

import httpx
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.routers.speech import get_speech_client

CHILD = str(uuid.uuid4())
OK_BODY = {
    "word_id": "w_001",
    "decision": "accepted",
    "score": 0.12,
    "threshold": 0.3,
    "threshold_source": "fallback",
    "nearest_variant": "spk_adult_01",
    "segments": [],
    "latency_ms": {"load": 1, "embed": 2, "dtw": 3, "total": 6},
}


def _client_with(handler):
    def override():
        with httpx.Client(base_url="http://speech", transport=httpx.MockTransport(handler)) as c:
            yield c

    app.dependency_overrides[get_speech_client] = override
    return TestClient(app)


@pytest.fixture(autouse=True)
def _clear_overrides():
    yield
    app.dependency_overrides.clear()


def _post(client, **data):
    form = {"word_id": "w_001", "language": "si", "child_id": CHILD} | data
    return client.post("/speech/assess", files={"audio": ("a.wav", b"RIFF..", "audio/wav")}, data=form)


def test_passes_through_service_response():
    seen = {}

    def handler(request: httpx.Request):
        seen["path"] = request.url.path
        seen["body"] = request.content
        return httpx.Response(200, json=OK_BODY)

    r = _post(_client_with(handler))
    assert r.status_code == 200 and r.json() == OK_BODY
    assert seen["path"] == "/assess"
    assert b'name="word_id"' in seen["body"] and b"RIFF.." in seen["body"]
    assert b"child_id" not in seen["body"]  # the model service never sees child identifiers


def test_service_4xx_detail_is_passed_through():
    r = _post(_client_with(lambda req: httpx.Response(400, json={"detail": "Audio is silent."})))
    assert r.status_code == 400 and r.json()["detail"] == "Audio is silent."


def test_service_503_detail_is_passed_through():
    body = {"detail": "No adult reference recording for w_001."}
    r = _post(_client_with(lambda req: httpx.Response(503, json=body)))
    assert r.status_code == 503 and r.json() == body


def test_service_down_is_503():
    def handler(request):
        raise httpx.ConnectError("refused")

    assert _post(_client_with(handler)).status_code == 503


def test_service_5xx_is_502():
    assert _post(_client_with(lambda req: httpx.Response(500))).status_code == 502


def test_bad_child_id_or_language_rejected_before_proxy():
    def handler(request):
        raise AssertionError("should not be called")

    client = _client_with(handler)
    assert _post(client, child_id="not-a-uuid").status_code == 422
    assert _post(client, language="fr").status_code == 422
