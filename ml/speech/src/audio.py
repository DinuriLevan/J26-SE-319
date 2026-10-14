"""Audio loading and validation: decode -> mono -> 16 kHz -> trim silence -> checks."""

from __future__ import annotations

import io
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly


class AudioValidationError(ValueError):
    """Input audio is unusable. The message is safe to return to the client."""


def _trim(wav: np.ndarray, sr: int, top_db: float) -> np.ndarray:
    """Trim leading/trailing frames quieter than (peak - top_db). Same idea as librosa.effects.trim."""
    frame = int(0.02 * sr)
    if wav.size < frame:
        return wav
    n = wav.size // frame
    rms = np.sqrt(np.mean(wav[: n * frame].reshape(n, frame) ** 2, axis=1) + 1e-12)
    db = 20 * np.log10(rms / rms.max())
    loud = np.flatnonzero(db > -top_db)
    return wav[loud[0] * frame : (loud[-1] + 1) * frame]


def load_audio(
    source: bytes | str | Path,
    target_sr: int = 16000,
    max_duration_s: float = 6.0,
    trim_top_db: float = 30.0,
    min_rms: float = 1e-3,
) -> np.ndarray:
    """Return float32 mono audio at target_sr with silence trimmed.

    Raises AudioValidationError for unreadable, too long, or silent input.
    """
    try:
        data = io.BytesIO(source) if isinstance(source, bytes) else source
        wav, sr = sf.read(data, dtype="float32", always_2d=True)
    except Exception as exc:  # soundfile raises several types for bad input
        raise AudioValidationError("Could not read audio. Please send a WAV file.") from exc

    wav = wav.mean(axis=1)
    if wav.size == 0:
        raise AudioValidationError("Audio is empty.")
    if wav.size / sr > max_duration_s:
        raise AudioValidationError(f"Audio is longer than {max_duration_s:g} s.")

    if sr != target_sr:
        g = np.gcd(sr, target_sr)
        wav = resample_poly(wav, target_sr // g, sr // g).astype(np.float32)

    if np.sqrt(np.mean(wav**2)) < min_rms:
        raise AudioValidationError("Audio is silent.")

    wav = _trim(wav, target_sr, trim_top_db)
    if wav.size < int(0.1 * target_sr):
        raise AudioValidationError("Audio is too short after trimming silence.")
    return wav
