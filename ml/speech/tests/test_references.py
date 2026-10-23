"""POST /references: developer tool for adding ADULT reference recordings (off by default)."""

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


@pytest.fixture
def setup(tmp_path):
    from tests.conftest import tone_word

    settings = load_settings()
    settings["paths"] = {
        "words_csv": tmp_path / "words.csv",
        "reference_dir": tmp_path / "reference",
        "embeddings_dir": tmp_path / "embeddings",
    }
    settings["scoring"]["fallback_threshold"] = 0.2
    settings["scoring"]["threshold_mode"] = "per_word"  # these tests cover the learned range
    (tmp_path / "words.csv").write_text(
        "word_id,text_si,text_en,language,grade,units\nw_001,,cat,en,2,k|æ|t\n", encoding="utf-8"
    )
    ref_dir = tmp_path / "reference" / "w_001"
    ref_dir.mkdir(parents=True)
    for i, spk in enumerate(["g3_s1_t01", "g4_s1_t01"]):
        sf.write(ref_dir / f"{spk}.wav", tone_word(WORD, [0.3, 0.35, 0.3], seed=i), 16000)
        (ref_dir / f"{spk}.json").write_text(
            json.dumps({"speaker_id": spk[:5], "age_group": "child", "units": []}), encoding="utf-8"
        )
    embedder = SpectralEmbedder()
    build(settings, embedder)
    return settings, embedder, ReferenceBank.from_settings(settings), tmp_path


def _post(client, wav, **form):
    data = {"word_id": "w_001", "language": "en", "speaker_id": "adult_01", "age_group": "adult"}
    return client.post(
        "/references", files={"audio": ("a.wav", wav, "audio/wav")}, data=data | form
    )


def test_disabled_by_default(setup, make_tone_word, to_wav_bytes):
    settings, embedder, bank, _ = setup
    with TestClient(create_app(settings, embedder, bank)) as c:
        assert _post(c, to_wav_bytes(make_tone_word(WORD, [0.3] * 3))).status_code in (404, 405)


def test_rejects_children_and_bad_speaker_ids(setup, make_tone_word, to_wav_bytes):
    settings, embedder, bank, root = setup
    wav = to_wav_bytes(make_tone_word(WORD, [0.3] * 3))
    with TestClient(create_app(settings, embedder, bank, allow_reference_upload=True)) as c:
        assert _post(c, wav, age_group="child").status_code == 422
        assert _post(c, wav, speaker_id="Bad Name!").status_code == 422
        assert _post(c, wav, word_id="w_999").status_code == 404
    assert len(list((root / "reference" / "w_001").glob("*.wav"))) == 2  # nothing saved


def test_adds_adult_reference_and_relearns_range(setup, make_tone_word, to_wav_bytes):
    settings, embedder, bank, root = setup
    with TestClient(create_app(settings, embedder, bank, allow_reference_upload=True)) as c:
        before = c.post(
            "/assess",
            files={"audio": ("a.wav", to_wav_bytes(make_tone_word(WORD, [0.3] * 3)), "audio/wav")},
            data={"word_id": "w_001", "language": "en"},
        ).json()
        assert before["threshold_source"] == "fallback"

        bodies = []
        for i, spk in enumerate(["adult_01", "adult_01", "adult_02"]):
            wav = to_wav_bytes(make_tone_word(WORD, [0.3 + 0.03 * i, 0.35, 0.3], seed=20 + i))
            r = _post(c, wav, speaker_id=spk, accent="en-lk")
            assert r.status_code == 200, r.text
            bodies.append(r.json())
        assert [b["ref_id"] for b in bodies] == ["adult_01_p01", "adult_01_p02", "adult_02_p01"]
        assert [b["n_refs"] for b in bodies] == [3, 4, 5]
        assert bodies[-1]["n_speakers"] == 4
        assert bodies[-1]["threshold_source"] == "bank"

        after = c.post(
            "/assess",
            files={"audio": ("a.wav", to_wav_bytes(make_tone_word(WORD, [0.3] * 3)), "audio/wav")},
            data={"word_id": "w_001", "language": "en"},
        ).json()
        assert after["threshold_source"] == "bank"  # the cached range was relearned

    meta = json.loads((root / "reference" / "w_001" / "adult_02_p01.json").read_text("utf-8"))
    assert meta["age_group"] == "adult" and meta["source"] == "app_recording"
    assert (root / "embeddings" / "w_001" / "adult_02_p01.npy").exists()
