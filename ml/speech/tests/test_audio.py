import numpy as np
import pytest

from src.audio import AudioValidationError, load_audio


def test_resamples_to_16k_and_downmixes_stereo(make_tone_word, to_wav_bytes):
    wav44 = make_tone_word([440, 880], [0.5, 0.5], sr=44100)
    out = load_audio(to_wav_bytes(wav44, sr=44100, channels=2))
    assert out.dtype == np.float32 and out.ndim == 1
    # 1.0 s of tones survives trimming at 16 kHz (to within a frame or two).
    assert abs(out.size / 16000 - 1.0) < 0.05


def test_trims_leading_and_trailing_silence(make_tone_word, to_wav_bytes):
    wav = make_tone_word([500], [0.6])  # 0.2 s silence each side
    out = load_audio(to_wav_bytes(wav))
    assert abs(out.size / 16000 - 0.6) < 0.05


def test_rejects_too_long(make_tone_word, to_wav_bytes):
    with pytest.raises(AudioValidationError, match="longer"):
        load_audio(to_wav_bytes(make_tone_word([500], [7.0])), max_duration_s=6.0)


def test_rejects_silence(to_wav_bytes):
    with pytest.raises(AudioValidationError, match="silent"):
        load_audio(to_wav_bytes(np.zeros(16000, dtype=np.float32)))


def test_rejects_non_audio_bytes():
    with pytest.raises(AudioValidationError, match="read"):
        load_audio(b"not a wav file")
