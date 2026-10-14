"""End-to-end /assess with tone "words" and the model-free SpectralEmbedder (no download)."""

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
        "word_id,text_si,text_en,language,grade,units\nw_001,කමල,,si,2,ක|ම|ල\n", encoding="utf-8"
    )
    ref_dir = root / "reference" / "w_001"
    ref_dir.mkdir(parents=True)
    for spk, age, durs in [
        ("spk_adult_01", "adult", [0.3, 0.3, 0.3]),
        ("spk_child_01", "child", [0.4] * 3),
    ]:
        sf.write(ref_dir / f"{spk}.wav", tone_word(WORD, durs, seed=1), 16000)
        (ref_dir / f"{spk}.json").write_text(
            json.dumps({"speaker_id": spk, "age_group": age, "accent": "standard", "units": []}),
            encoding="utf-8",
        )
    embedder = SpectralEmbedder()
    build(settings, embedder)
    bank = ReferenceBank.from_settings(settings)
    return settings, embedder, bank


@pytest.fixture(scope="module")
def client(setup):
    with TestClient(create_app(*setup)) as c:
        yield c


def _post(client, wav, word_id="w_001", language="si"):
    return client.post(
        "/assess",
        files={"audio": ("a.wav", wav, "audio/wav")},
        data={"word_id": word_id, "language": language},
    )


def test_health(client):
    assert client.get("/health").json()["status"] == "ok"


def test_correct_word_accepted_slower_and_louder(client, make_tone_word, to_wav_bytes):
    wav = make_tone_word(WORD, [0.45, 0.5, 0.4], amp=0.6, seed=2)
    r = _post(client, to_wav_bytes(wav))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["decision"] == "accepted"
    assert body["threshold_source"] == "fallback"
    assert body["nearest_variant"] == "spk_adult_01"  # baseline = first adult only
    assert body["segments"] == []
    assert set(body["latency_ms"]) == {"load", "embed", "dtw", "total"}


def test_wrong_middle_unit_needs_remediation(client, make_tone_word, to_wav_bytes):
    r = _post(client, to_wav_bytes(make_tone_word(WRONG, [0.3, 0.3, 0.3], seed=3)))
    body = r.json()
    assert body["decision"] == "needs_remediation"
    assert body["score"] > body["threshold"]


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
