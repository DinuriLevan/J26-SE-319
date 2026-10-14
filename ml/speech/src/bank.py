"""Reference bank access: words.csv, reference/<word_id>/<speaker_id>.json, embeddings/*.npy.

Stage 1 only needs a single baseline reference per word. The multi-reference bank and its
learned acceptance range are added in Stage 3.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Any

import numpy as np

MANIFEST = "manifest.json"


class BankError(RuntimeError):
    pass


class ReferenceBank:
    def __init__(self, words_csv: Path, reference_dir: Path, embeddings_dir: Path):
        self.reference_dir = Path(reference_dir)
        self.embeddings_dir = Path(embeddings_dir)
        with open(words_csv, encoding="utf-8") as f:
            self.words: dict[str, dict[str, str]] = {r["word_id"]: r for r in csv.DictReader(f)}

    @classmethod
    def from_settings(cls, settings: dict) -> "ReferenceBank":
        p = settings["paths"]
        return cls(p["words_csv"], p["reference_dir"], p["embeddings_dir"])

    def embedder_name(self) -> str | None:
        path = self.embeddings_dir / MANIFEST
        if not path.exists():
            return None
        return json.loads(path.read_text(encoding="utf-8")).get("embedder")

    def check_embedder(self, name: str) -> None:
        """Reference embeddings must come from the same embedder used at inference time."""
        built_with = self.embedder_name()
        if built_with != name:
            raise BankError(
                f"Reference embeddings were built with {built_with!r} but the service uses "
                f"{name!r}. Re-run scripts/build_embeddings.py."
            )

    def references(self, word_id: str) -> list[dict[str, Any]]:
        """Metadata of every reference that has an embedding, sorted by speaker_id."""
        out = []
        for meta_path in sorted((self.reference_dir / word_id).glob("*.json")):
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
            if (self.embeddings_dir / word_id / f"{meta['speaker_id']}.npy").exists():
                out.append(meta)
        return out

    def embedding(self, word_id: str, speaker_id: str) -> np.ndarray:
        return np.load(self.embeddings_dir / word_id / f"{speaker_id}.npy")

    def baseline_reference(self, word_id: str, speaker_id: str | None = None) -> dict[str, Any]:
        """The single adult reference used by the Stage 1 baseline (configured, else first adult)."""
        refs = self.references(word_id)
        if speaker_id:
            refs = [r for r in refs if r["speaker_id"] == speaker_id]
        else:
            refs = [r for r in refs if r.get("age_group") == "adult"]
        if not refs:
            raise BankError(f"No adult reference recording for {word_id}.")
        ref = dict(refs[0])
        ref["emb"] = self.embedding(word_id, ref["speaker_id"])
        return ref
