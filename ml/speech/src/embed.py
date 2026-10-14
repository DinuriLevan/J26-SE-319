"""Frame-level embeddings: one vector per ~20 ms frame.

XLSREmbedder runs facebook/wav2vec2-xls-r-300m and returns one hidden layer.
SpectralEmbedder is a model-free stand-in (log band energies) with the same interface, used by
tests and for running the service without downloading the model. Never use it for evaluation.
"""

from __future__ import annotations

from typing import Protocol

import numpy as np


class Embedder(Protocol):
    name: str

    def embed(self, wav: np.ndarray) -> np.ndarray:
        """wav: float32 mono 16 kHz -> (frames, dim) float32."""
        ...


class XLSREmbedder:
    def __init__(self, model_name: str = "facebook/wav2vec2-xls-r-300m", layer: int = 12):
        import torch
        from transformers import AutoFeatureExtractor, Wav2Vec2Model

        self._torch = torch
        self.layer = layer
        self.name = f"{model_name}@layer{layer}"
        self.extractor = AutoFeatureExtractor.from_pretrained(model_name)
        self.model = Wav2Vec2Model.from_pretrained(model_name)
        self.model.eval()
        # Truncating the encoder to layer+1 layers is a Stage 2 optimisation, enabled only
        # after it is verified with np.allclose against hidden_states[layer] of the full model.

    def embed(self, wav: np.ndarray) -> np.ndarray:
        inputs = self.extractor(wav, sampling_rate=16000, return_tensors="pt")
        with self._torch.inference_mode():
            out = self.model(inputs.input_values, output_hidden_states=True)
        return out.hidden_states[self.layer][0].numpy().astype(np.float32)


class SpectralEmbedder:
    """Log-energy in n_bands linear frequency bands per 20 ms frame (25 ms window)."""

    def __init__(self, n_bands: int = 32, sr: int = 16000):
        self.n_bands = n_bands
        self.sr = sr
        self.name = f"spectral{n_bands}"

    def embed(self, wav: np.ndarray) -> np.ndarray:
        hop, win = int(0.02 * self.sr), int(0.025 * self.sr)
        if wav.size < win:
            wav = np.pad(wav, (0, win - wav.size))
        n = 1 + (wav.size - win) // hop
        idx = np.arange(win)[None, :] + hop * np.arange(n)[:, None]
        frames = wav[idx] * np.hanning(win)
        power = np.abs(np.fft.rfft(frames, axis=1)) ** 2
        bands = np.array_split(power, self.n_bands, axis=1)
        feats = np.log(np.stack([b.sum(axis=1) for b in bands], axis=1) + 1e-6)
        # Remove per-frame level so cosine distance compares spectral shape, not loudness.
        return (feats - feats.mean(axis=1, keepdims=True)).astype(np.float32)


def make_embedder(kind: str, settings: dict) -> Embedder:
    if kind == "xlsr":
        emb = settings["embedding"]
        return XLSREmbedder(emb["model_name"], emb["layer"])
    if kind == "spectral":
        return SpectralEmbedder()
    raise ValueError(f"Unknown embedder: {kind}")
