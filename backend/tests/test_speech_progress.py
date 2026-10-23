"""phoneme_progress via POST /speech/assess-unit and GET /speech/progress (SQLite in memory, service mocked)."""

import uuid

import httpx
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.db import get_db
from app.main import app
from app.models import ChildProfile
from app.models.base import Base
from app.routers.speech import get_speech_client

CHILD = uuid.uuid4()


@pytest.fixture
def client():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    event.listen(engine, "connect", lambda conn, _: conn.execute("PRAGMA foreign_keys=ON"))
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    with Session() as s:
        s.add(ChildProfile(id=CHILD, name="Learner", preferred_language="si"))
        s.commit()

    def db_override():
        with Session() as s:
            yield s

    state = {"decision": "accepted", "score": 0.1, "label": "ම"}

    def handler(request: httpx.Request):
        return httpx.Response(200, json={"word_id": "w_002", **state})

    def speech_override():
        with httpx.Client(base_url="http://speech", transport=httpx.MockTransport(handler)) as c:
            yield c

    app.dependency_overrides[get_db] = db_override
    app.dependency_overrides[get_speech_client] = speech_override
    yield TestClient(app), state
    app.dependency_overrides.clear()


def _unit(c, start=0, end=0, child=CHILD):
    return c.post(
        "/speech/assess-unit",
        files={"audio": ("u.wav", b"RIFF..", "audio/wav")},
        data={"word_id": "w_002", "language": "si", "start_unit": start, "end_unit": end, "child_id": str(child)},
    )


def test_unit_attempts_update_progress_and_mastery(client):
    c, state = client
    assert _unit(c).status_code == 200
    state.update(decision="needs_remediation", score=0.6)
    assert _unit(c).json()["decision"] == "needs_remediation"
    rows = c.get(f"/speech/progress/{CHILD}").json()
    assert len(rows) == 1
    r = rows[0]
    assert (r["unit_label"], r["language"], r["attempts"], r["successes"]) == ("ම", "si", 2, 1)
    assert r["last_score"] == 0.6
    assert r["mastery"] == pytest.approx(0.7 * 0.3)  # 0 -> 0.3 (pass) -> 0.21 (fail)


def test_blends_are_not_recorded_as_units(client):
    c, state = client
    state.update(label="මම")
    assert _unit(c, 0, 1).status_code == 200
    assert c.get(f"/speech/progress/{CHILD}").json() == []


def test_unsynced_child_still_gets_a_score(client):
    c, _ = client
    stranger = uuid.uuid4()  # no child_profiles row yet: FK fails, the score is still returned
    r = _unit(c, child=stranger)
    assert r.status_code == 200 and r.json()["decision"] == "accepted"
    assert c.get(f"/speech/progress/{stranger}").json() == []


def test_progress_lists_lowest_mastery_first(client):
    c, state = client
    state.update(label="ම", decision="accepted")
    _unit(c)
    state.update(label="ට", decision="needs_remediation")
    _unit(c)
    labels = [r["unit_label"] for r in c.get(f"/speech/progress/{CHILD}").json()]
    assert labels == ["ට", "ම"]
