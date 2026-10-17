"""Remediation endpoints: GET /words, POST /assess_unit, GET /listen (adult model audio only)."""

import io
import json
import sys
from pathlib import Path

import pytest
import soundfile as sf
from fastapi.testclient import TestClient

from src.bank import ReferenceBank
from src.embed import SpectralEmbedder
from src.service import create_app
from src.settings import load_settings

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from build_embeddings import build  # noqa: E402

WORD = [440, 880, 660]
DURS = [0.3, 0.35, 0.3]


@pytest.fixture(scope="module")
def client(tmp_path_factory):
    from tests.conftest import tone_word

    root = tmp_path_factory.mktemp("units")
    settings = load_settings()
    settings["paths"] = {
        "words_csv": root / "words.csv",
        "reference_dir": root / "reference",
        "embeddings_dir": root / "embeddings",
    }
    (root / "words.csv").write_text(
        "word_id,text_si,text_en,language,grade,units\n"
        "w_001,,cat,en,2,c|a|t\n"
        "w_002,,sun,en,2,s|u|n\n",
        encoding="utf-8",
    )
    speakers = {
        "w_001": [
            ("adult_01_p01", "adult_01", "adult"),
            ("adult_02_p01", "adult_02", "adult"),
            ("g3_s1_t01", "g3_s1", "child"),
            ("g3_s3_t01", "g3_s3", "child"),
            ("g4_s1_t01", "g4_s1", "child"),
        ],
        "w_002": [("g3_s1_t01", "g3_s1", "child"), ("g4_s1_t01", "g4_s1", "child")],
    }
    for word_id, refs in speakers.items():
        d = root / "reference" / word_id
        d.mkdir(parents=True)
        for i, (ref_id, spk, age) in enumerate(refs):
            # Speakers differ: pitch +-4%, loudness and length vary, like real references.
            durs = [x + 0.02 * i for x in DURS]
            freqs = [f * (1 + 0.02 * (i - 2)) for f in WORD]
            amp = 0.2 + 0.05 * i
            sf.write(d / f"{ref_id}.wav", tone_word(freqs, durs, amp=amp, seed=30 + i), 16000)
            t, units = 0.0, []
            for label, du in zip("cat", durs):
                units.append({"label": label, "start_s": round(t, 3), "end_s": round(t + du, 3)})
                t += du
            meta = {"speaker_id": spk, "age_group": age, "units": units}
            (d / f"{ref_id}.json").write_text(json.dumps(meta), encoding="utf-8")
    embedder = SpectralEmbedder()
    build(settings, embedder)
    with TestClient(create_app(settings, embedder, ReferenceBank.from_settings(settings))) as c:
        yield c


def _unit(client, wav, a, b, word_id="w_001"):
    return client.post(
        "/assess_unit",
        files={"audio": ("u.wav", wav, "audio/wav")},
        data={"word_id": word_id, "language": "en", "start_unit": a, "end_unit": b},
    )


def test_words_lists_units_and_adult_audio(client):
    words = {w["word_id"]: w for w in client.get("/words").json()}
    assert words["w_001"]["units"] == ["c", "a", "t"]
    assert words["w_001"]["listen_units"] == [0, 1, 2] and words["w_001"]["has_word_audio"]
    assert words["w_002"]["listen_units"] == [] and not words["w_002"]["has_word_audio"]


def test_assess_unit_accepts_right_sound_rejects_wrong(client, make_tone_word, to_wav_bytes):
    ok = _unit(client, to_wav_bytes(make_tone_word([880], [0.4], seed=40)), 1, 1).json()
    assert ok["label"] == "a" and ok["threshold_source"] == "bank"
    assert ok["decision"] == "accepted", ok
    wrong = _unit(client, to_wav_bytes(make_tone_word([1500], [0.4], seed=41)), 1, 1).json()
    assert wrong["decision"] == "needs_remediation", wrong
    assert wrong["score"] > ok["score"]


def test_assess_blend_span(client, make_tone_word, to_wav_bytes):
    body = _unit(
        client, to_wav_bytes(make_tone_word([880, 660], [0.4, 0.35], seed=42)), 1, 2
    ).json()
    assert body["label"] == "at" and body["decision"] == "accepted", body


def test_assess_unit_rejects_bad_spans(client, make_tone_word, to_wav_bytes):
    wav = to_wav_bytes(make_tone_word([880], [0.4]))
    assert _unit(client, wav, 2, 1).status_code == 422
    assert _unit(client, wav, 0, 3).status_code == 422
    assert _unit(client, wav, 0, 0, word_id="w_999").status_code == 404


def test_listen_serves_adult_audio_only(client):
    r = client.get("/listen/w_001", params={"start_unit": 1, "end_unit": 1})
    assert r.status_code == 200 and r.headers["content-type"] == "audio/wav"
    assert r.headers["x-ref-id"].startswith("adult_")
    wav, sr = sf.read(io.BytesIO(r.content))
    assert sr == 16000 and wav.size > 0.3 * sr  # unit + 0.15 s padding each side
    whole = client.get("/listen/w_001")
    assert whole.status_code == 200 and whole.headers["x-ref-id"].startswith("adult_")


def test_listen_404_when_only_children_recorded(client):
    assert client.get("/listen/w_002").status_code == 404
    assert client.get("/listen/w_002", params={"start_unit": 0, "end_unit": 0}).status_code == 404
    assert client.get("/listen/w_001", params={"start_unit": 0}).status_code == 422
