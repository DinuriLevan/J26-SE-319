import io

import numpy as np
import pytest
import soundfile as sf


def tone_word(freqs, durs_s, sr=16000, amp=0.3, seed=0):
    """A synthetic "word": one tone per unit, with short silences at both ends and light noise."""
    rng = np.random.default_rng(seed)
    parts = [np.zeros(int(0.2 * sr))]
    for f, d in zip(freqs, durs_s):
        t = np.arange(int(d * sr)) / sr
        parts.append(amp * np.sin(2 * np.pi * f * t))
    parts.append(np.zeros(int(0.2 * sr)))
    wav = np.concatenate(parts)
    return (wav + rng.normal(scale=0.002, size=wav.size)).astype(np.float32)


def wav_bytes(wav, sr=16000, channels=1):
    data = np.stack([wav] * channels, axis=1) if channels > 1 else wav
    buf = io.BytesIO()
    sf.write(buf, data, sr, format="WAV", subtype="PCM_16")
    return buf.getvalue()


@pytest.fixture
def make_tone_word():
    return tone_word


@pytest.fixture
def to_wav_bytes():
    return wav_bytes
