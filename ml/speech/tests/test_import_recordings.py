"""scripts/import_recordings.py: single-word field recordings -> reference bank (synthetic audio only)."""

import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest
import soundfile as sf

from src.settings import load_settings

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from import_recordings import import_folder, match_files, word_key  # noqa: E402

WORDS = pd.DataFrame(
    {
        "word_id": ["w_001", "w_040", "w_016", "w_038", "w_005", "w_017", "w_043"],
        "text_si": ["අම්මා", "පූසා", "පාසල්", "වතුර", "", "", ""],
        "text_en": ["mother", "cat", "school", "water", "cat", "hat", "boy"],
        "language": ["si", "si", "si", "si", "en", "en", "en"],
    }
)


@pytest.mark.parametrize(
    "name,key",
    [
        ("අම්මා.WAV", "අම්මා"),
        ("ගස .WAV", "ගස"),
        ("වතුර  (1).WAV", "වතුර"),
        ("අත(1).WAV", "අත"),
        ("පුසා.WAV", "පූසා"),  # owner-confirmed spelling aliases
        ("පාසල.WAV", "පාසල්"),
        ("මල්ලී.WAV", "මල්ලි"),
    ],
)
def test_word_key(name, key):
    assert word_key(name) == key


def test_match_files_english_typos():
    files = [Path("boy9.WAV"), Path("hart.WAV"), Path("Cat.WAV"), Path("9.WAV"), Path("cats.WAV")]
    matched, unmatched = match_files(files, WORDS, "en")
    assert {k: [f.name for f in v] for k, v in matched.items()} == {
        "w_043": ["boy9.WAV"],
        "w_017": ["hart.WAV"],
        "w_005": ["Cat.WAV"],
    }
    assert unmatched == ["9.WAV", "cats.WAV"]


def test_match_files_reports_unknown_names():
    files = [Path("අම්මා.WAV"), Path("පුසා.WAV"), Path("වතුර .WAV"), Path("වතුර  (1).WAV"),
             Path("බෝලය.WAV")]
    matched, unmatched = match_files(files, WORDS, "si")
    assert {k: len(v) for k, v in matched.items()} == {"w_001": 1, "w_040": 1, "w_038": 2}
    assert unmatched == ["බෝලය.WAV"]


@pytest.fixture
def env(tmp_path):
    settings = load_settings()
    settings["paths"]["reference_dir"] = tmp_path / "reference"
    src = tmp_path / "src"
    src.mkdir()
    t = np.arange(int(0.6 * 44100)) / 44100
    tone = 0.3 * np.sin(2 * np.pi * 440 * t)
    for name in ["අම්මා.WAV", "පුසා .WAV", "වතුර.WAV", "වතුර (1).WAV"]:
        sf.write(src / name, np.stack([tone, tone], axis=1), 44100, subtype="PCM_16")
    return settings, src, tmp_path / "reference"


def test_import_writes_16k_mono_references_with_metadata(env):
    settings, src, ref = env
    r = import_folder(src, "si_c1", "child", "si", settings, WORDS)
    assert (r["written"], r["words"], r["missing"]) == (4, 3, ["w_016"])
    wav, sr = sf.read(ref / "w_040" / "si_c1_r01.wav")
    assert sr == 16000 and wav.ndim == 1 and abs(wav.size / sr - 0.6) < 0.01
    assert sorted(p.name for p in (ref / "w_038").glob("*.wav")) == ["si_c1_r01.wav", "si_c1_r02.wav"]
    meta = json.loads((ref / "w_040" / "si_c1_r01.json").read_text(encoding="utf-8"))
    assert meta["speaker_id"] == "si_c1" and meta["age_group"] == "child"
    assert meta["source"] == "field_recording" and meta["recorded_from"] == "පුසා .WAV"
    assert meta["units"] == []


def test_reimport_replaces_only_that_speakers_field_recordings(env):
    settings, src, ref = env
    import_folder(src, "si_c1", "child", "si", settings, WORDS)
    other = ref / "w_001" / "g3_s1_t01.json"
    other.write_text(json.dumps({"speaker_id": "g3_s1", "source": "child_corpus"}), encoding="utf-8")
    (src / "වතුර (1).WAV").unlink()
    r = import_folder(src, "si_c1", "child", "si", settings, WORDS)
    assert r["removed"] == 4 and r["written"] == 3
    assert not (ref / "w_038" / "si_c1_r02.wav").exists()
    assert other.exists()


def test_refuses_test_speakers_unknown_files_and_silence(env):
    settings, src, ref = env
    with pytest.raises(SystemExit, match="test speaker"):
        import_folder(src, settings["corpus"]["test_speakers"][0], "child", "si", settings, WORDS)
    sf.write(src / "බෝලය.WAV", np.zeros(8000), 16000)
    with pytest.raises(SystemExit, match="No practice word"):
        import_folder(src, "si_c1", "child", "si", settings, WORDS)
    (src / "බෝලය.WAV").unlink()
    sf.write(src / "අම්මා.WAV", np.zeros(8000), 16000)
    with pytest.raises(SystemExit, match="අම්මා"):
        import_folder(src, "si_c1", "child", "si", settings, WORDS)
    assert not ref.exists()  # nothing written when any file is bad


def test_replace_speaker_removes_the_old_ids_field_recordings_only(env):
    settings, src, ref = env
    import_folder(src, "si_c1", "child", "si", settings, WORDS)
    keep = ref / "w_001" / "g3_s1_t01.json"
    keep.write_text(json.dumps({"speaker_id": "g3_s1", "source": "child_corpus"}), encoding="utf-8")
    r = import_folder(src, "fr_c1", "child", "si", settings, WORDS, replace_speakers=("si_c1",))
    assert r["removed"] == 4 and r["written"] == 4
    assert not list(ref.glob("*/si_c1_*")) and len(list(ref.glob("*/fr_c1_*.wav"))) == 4
    assert keep.exists()


def test_importing_another_language_keeps_the_speakers_first_language(env):
    settings, src, ref = env
    import_folder(src, "fr_a1", "adult", "si", settings, WORDS)
    en = src.parent / "en"
    en.mkdir()
    sf.write(en / "boy9.WAV", sf.read(src / "අම්මා.WAV")[0], 44100, subtype="PCM_16")
    r = import_folder(en, "fr_a1", "adult", "en", settings, WORDS)
    assert r["removed"] == 0 and r["written"] == 1
    assert len(list(ref.glob("*/fr_a1_*.wav"))) == 5  # 4 Sinhala + 1 English
