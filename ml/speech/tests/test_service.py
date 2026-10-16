"""End-to-end /assess with tone "words" and the model-free SpectralEmbedder (no download)."""

import copy
import json
import sys
from pathlib import Path

import pytest
import soundfile as sf
from fastapi.testclient import TestClient

from src.bank import BankError, ReferenceBank
from src.embed import SpectralEmbedder
from src.service import create_app
from src.settings import load_settings

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from build_embeddings import build  # noqa: E402

WORD = [440, 880, 660]  # w_001 = three "units"
WRONG = [440, 1500, 660]  # 2nd unit replaced


@pytest.fixture(scope="module")
def setup(tmp_path_factory):
    from tests.conftest import tone_word

    root = tmp_path_factory.mktemp("speech")
    settings = load_settings()
    settings["paths"] = {
        "words_csv": root / "words.csv",
        "reference_dir": root / "reference",
        "embeddings_dir": root / "embeddings",
    }
    settings["scoring"]["fallback_threshold"] = 0.2  # test fixture value, not a tuned threshold
    (root / "words.csv").write_text(
        "word_id,text_si,text_en,language,grade,units\n"
        "w_001,කමල,,si,2,ක|ම|ල\n"
        "w_002,,cat,en,2,k|æ|t\n",
        encoding="utf-8",
    )
    # w_001: 2 references -> fallback threshold. w_002: 5 references -> range learned from the
    # bank, including an "accent variant" whose middle unit differs slightly (900 vs 880 Hz).
    variant = [440, 900, 660]
    refs = {
        "w_001": [
            ("spk_adult_01", "adult", WORD, [0.3] * 3),
            ("spk_child_01", "child", WORD, [0.4] * 3),
        ],
        "w_002": [
            ("spk_adult_01", "adult", WORD, [0.3, 0.3, 0.3]),
            ("spk_adult_02", "adult", WORD, [0.25, 0.35, 0.3]),
            ("spk_child_01", "child", WORD, [0.4, 0.45, 0.4]),
            ("spk_child_02", "child", variant, [0.35, 0.4, 0.35]),
            ("spk_child_03", "child", variant, [0.4, 0.35, 0.45]),
        ],
    }
    for word_id, spks in refs.items():
        ref_dir = root / "reference" / word_id
        ref_dir.mkdir(parents=True)
        for i, (spk, age, freqs, durs) in enumerate(spks):
            sf.write(ref_dir / f"{spk}.wav", tone_word(freqs, durs, seed=10 + i), 16000)
            # w_002 refs get unit boundaries (one unit per tone; silence is trimmed on load).
            t, units = 0.0, []
            if word_id == "w_002":
                for label, d in zip("cat", durs):
                    units.append({"label": label, "start_s": t, "end_s": t + d})
                    t += d
            (ref_dir / f"{spk}.json").write_text(
                json.dumps(
                    {"speaker_id": spk, "age_group": age, "accent": "standard", "units": units}
                ),
                encoding="utf-8",
            )
    embedder = SpectralEmbedder()
    build(settings, embedder)
    bank = ReferenceBank.from_settings(settings)
    return settings, embedder, bank


def _client(setup, mode):
    settings, embedder, bank = setup
    settings = copy.deepcopy(settings)
    settings["scoring"]["mode"] = mode
    return TestClient(create_app(settings, embedder, bank))


@pytest.fixture(scope="module")
def client(setup):
    with _client(setup, "bank") as c:
        yield c


@pytest.fixture(scope="module")
def single_client(setup):
    with _client(setup, "single") as c:
        yield c


def _post(client, wav, word_id="w_001", language="si"):
    return client.post(
        "/assess",
        files={"audio": ("a.wav", wav, "audio/wav")},
        data={"word_id": word_id, "language": language},
    )


def test_health(client):
    assert client.get("/health").json()["status"] == "ok"


def test_single_mode_uses_first_adult_and_fallback(single_client, make_tone_word, to_wav_bytes):
    wav = make_tone_word(WORD, [0.45, 0.5, 0.4], amp=0.6, seed=2)
    body = _post(single_client, to_wav_bytes(wav), word_id="w_002", language="en").json()
    assert body["decision"] == "accepted"
    assert body["threshold_source"] == "fallback"
    assert body["nearest_variant"] == "spk_adult_01"  # baseline = first adult only
    assert body["segments"] == []
    assert set(body["latency_ms"]) == {"load", "embed", "dtw", "total"}


def test_bank_mode_falls_back_below_four_refs(client, make_tone_word, to_wav_bytes):
    wav = make_tone_word(WORD, [0.45, 0.5, 0.4], amp=0.6, seed=2)
    body = _post(client, to_wav_bytes(wav)).json()
    assert body["threshold_source"] == "fallback"
    assert body["threshold"] == 0.2
    assert body["decision"] == "accepted"


def test_bank_mode_learned_range_accepts_correct_and_variant(client, make_tone_word, to_wav_bytes):
    for freqs in (WORD, [440, 900, 660]):
        wav = make_tone_word(freqs, [0.45, 0.5, 0.4], amp=0.6, seed=3)
        body = _post(client, to_wav_bytes(wav), word_id="w_002", language="en").json()
        assert body["threshold_source"] == "bank"
        assert body["decision"] == "accepted", body
        assert body["nearest_variant"].startswith("spk_")


def test_bank_mode_learned_range_rejects_wrong_middle_unit(client, make_tone_word, to_wav_bytes):
    wav = make_tone_word(WRONG, [0.3, 0.3, 0.3], seed=4)
    body = _post(client, to_wav_bytes(wav), word_id="w_002", language="en").json()
    assert body["threshold_source"] == "bank"
    assert body["decision"] == "needs_remediation"
    assert body["score"] > body["threshold"]
    # Localisation: the middle unit (the wrong tone) is flagged, with an error type.
    segs = body["segments"]
    assert [s["label"] for s in segs] == ["c", "a", "t"]
    assert [s["label"] for s in segs if s["status"] == "flagged"][0] == "a"
    flagged = [s for s in segs if s["status"] == "flagged"]
    assert all(
        s["error_type"] in {"substitution", "omission", "insertion", "distortion"} for s in flagged
    )


def test_accepted_attempt_has_no_segments(client, make_tone_word, to_wav_bytes):
    wav = make_tone_word(WORD, [0.45, 0.5, 0.4], amp=0.6, seed=3)
    body = _post(client, to_wav_bytes(wav), word_id="w_002", language="en").json()
    assert body["decision"] == "accepted" and body["segments"] == []


@pytest.mark.parametrize(
    "kwargs,status",
    [({"word_id": "w_999"}, 404), ({"language": "en"}, 422), ({"language": "fr"}, 422)],
)
def test_bad_word_or_language(client, make_tone_word, to_wav_bytes, kwargs, status):
    r = _post(client, to_wav_bytes(make_tone_word(WORD, [0.3] * 3)), **kwargs)
    assert r.status_code == status


def test_bad_audio_is_400(client, to_wav_bytes):
    import numpy as np

    assert _post(client, b"garbage").status_code == 400
    assert _post(client, to_wav_bytes(np.zeros(16000, dtype=np.float32))).status_code == 400


def test_refuses_bank_built_with_other_embedder(setup):
    settings, _, bank = setup
    with pytest.raises(BankError, match="Re-run"):
        create_app(settings, SpectralEmbedder(n_bands=16), bank)
