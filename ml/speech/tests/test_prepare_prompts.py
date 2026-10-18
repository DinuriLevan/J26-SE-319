import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from prepare_prompts import (  # noqa: E402
    PEAK_LIMIT,
    PROMPT_KEYS,
    SAMPLE_RATE,
    TARGET_RMS_DB,
    convert,
    load_texts,
    write_script,
)


def test_every_prompt_key_has_text_in_both_languages(tmp_path):
    texts = load_texts()  # the real ARB files
    assert set(texts) == {"en", "si"}
    for lang in texts:
        assert all(texts[lang][k].strip() for k in PROMPT_KEYS)
    out = tmp_path / "script.md"
    write_script(texts, out)
    body = out.read_text(encoding="utf-8")
    assert all(f"`{k}`" in body for k in PROMPT_KEYS)
    assert texts["si"]["speechListen"] in body


def test_convert_cleans_audio_and_reports(tmp_path):
    from tests.conftest import tone_word

    raw = tmp_path / "raw"
    (raw / "en").mkdir(parents=True)
    (raw / "si").mkdir(parents=True)
    # 44.1 kHz stereo with silence around it (tone_word adds 0.2 s each side) and a realistic
    # noise floor (about -43 dB below the voice), not yet loudness-normalised.
    quiet = tone_word([300, 500], [0.4, 0.4], sr=44100, amp=0.3)
    sf.write(raw / "en" / "speechListen.wav", np.stack([quiet, quiet], 1), 44100)
    sf.write(raw / "si" / "speechListen.wav", quiet, 44100)
    sf.write(raw / "en" / "notAPrompt.wav", quiet, 44100)

    out = tmp_path / "assets"
    report = convert(raw, out)
    assert sorted(report["converted"]) == ["en/speechListen", "si/speechListen"]
    assert "en/notAPrompt" in report["unexpected"]
    assert len(report["missing"]) == 2 * len(PROMPT_KEYS) - 2

    wav, sr = sf.read(out / "en" / "speechListen.wav")
    assert sr == SAMPLE_RATE and wav.ndim == 1
    assert abs(wav.size / sr - 0.8) < 0.06  # silence trimmed
    rms_db = 20 * np.log10(np.sqrt(np.mean(wav**2)))
    assert abs(rms_db - TARGET_RMS_DB) < 1.5  # loudness normalised
    assert np.max(np.abs(wav)) <= PEAK_LIMIT + 1e-3
    assert abs(wav[0]) < 1e-3 and abs(wav[-1]) < 1e-3  # faded in/out
