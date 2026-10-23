"""Build a synthetic reference bank so the pipeline runs without audio or the XLS-R model.

Each speech unit (akshara/syllable) gets a fixed random "prototype" embedding. A speaker's
utterance of a word is the concatenation of its units' prototypes, each held for a random
number of ~20 ms frames, plus a speaker-level accent offset and per-frame noise. Child
speakers are slower and noisier than adults. No audio is written.

Output layout (under --out, default ml/speech/data):
    words.csv
    reference/<word_id>/<speaker_id>.json   # speaker_id, age_group, accent, units:[{label,start_s,end_s}]
    embeddings/<word_id>/<speaker_id>.npy   # float32 [frames, dim]

Usage:
    python scripts/make_synthetic_bank.py [--out data] [--seed 0] [--dim 64]
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import numpy as np

FRAME_S = 0.02  # wav2vec2 frame hop is ~20 ms

WORDS = [
    # word_id, text_si, text_en, language, grade, units
    ("w_001", "කමල", "", "si", 2, ["ක", "ම", "ල"]),
    ("w_002", "අම්මා", "", "si", 2, ["අ", "ම්මා"]),
    ("w_003", "පාසල", "", "si", 3, ["පා", "ස", "ල"]),
    ("w_004", "", "cat", "en", 2, ["k", "æ", "t"]),
    ("w_005", "", "sun", "en", 2, ["s", "ʌ", "n"]),
]

SPEAKERS = [
    # speaker_id, age_group, accent
    ("spk_adult_01", "adult", "standard"),
    ("spk_adult_02", "adult", "standard"),
    ("spk_adult_03", "adult", "regional"),
    ("spk_child_01", "child", "standard"),
    ("spk_child_02", "child", "regional"),
]

# Mean frames per unit and noise level per age group (children: slower and more variable).
AGE_PROFILE = {
    "adult": {"mean_frames": 8, "noise": 0.15},
    "child": {"mean_frames": 11, "noise": 0.25},
}
ACCENT_SHIFT = {"standard": 0.0, "regional": 0.35}


def _unit_prototypes(rng: np.random.Generator, dim: int) -> dict[str, np.ndarray]:
    labels = sorted({u for *_, units in WORDS for u in units})
    return {label: rng.normal(size=dim).astype(np.float32) for label in labels}


def synth_utterance(
    rng: np.random.Generator,
    units: list[str],
    prototypes: dict[str, np.ndarray],
    accent_offset: np.ndarray,
    age_group: str,
) -> tuple[np.ndarray, list[dict]]:
    """Return (frames [T, dim], unit boundaries in seconds)."""
    profile = AGE_PROFILE[age_group]
    chunks, boundaries, t = [], [], 0
    for label in units:
        n = max(3, int(rng.poisson(profile["mean_frames"])))
        base = prototypes[label] + accent_offset
        noise = rng.normal(scale=profile["noise"], size=(n, base.size))
        chunks.append((base + noise).astype(np.float32))
        boundaries.append(
            {
                "label": label,
                "start_s": round(t * FRAME_S, 3),
                "end_s": round((t + n) * FRAME_S, 3),
            }
        )
        t += n
    return np.concatenate(chunks, axis=0), boundaries


def build_bank(out_dir: Path, seed: int = 0, dim: int = 64) -> None:
    rng = np.random.default_rng(seed)
    prototypes = _unit_prototypes(rng, dim)
    accent_dirs = {
        accent: shift * rng.normal(size=dim).astype(np.float32) / np.sqrt(dim)
        for accent, shift in ACCENT_SHIFT.items()
    }

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "embeddings").mkdir(exist_ok=True)
    # Marks these as synthetic so the service refuses to score real audio against them.
    (out_dir / "embeddings" / "manifest.json").write_text(
        json.dumps({"embedder": "synthetic", "dim": dim}), encoding="utf-8"
    )
    with open(out_dir / "words.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["word_id", "text_si", "text_en", "language", "grade", "units"])
        for word_id, text_si, text_en, language, grade, units in WORDS:
            writer.writerow([word_id, text_si, text_en, language, grade, "|".join(units)])

    for word_id, *_, units in WORDS:
        ref_dir = out_dir / "reference" / word_id
        emb_dir = out_dir / "embeddings" / word_id
        ref_dir.mkdir(parents=True, exist_ok=True)
        emb_dir.mkdir(parents=True, exist_ok=True)
        for speaker_id, age_group, accent in SPEAKERS:
            frames, boundaries = synth_utterance(
                rng, units, prototypes, accent_dirs[accent], age_group
            )
            np.save(emb_dir / f"{speaker_id}.npy", frames)
            meta = {
                "speaker_id": speaker_id,
                "age_group": age_group,
                "accent": accent,
                "synthetic": True,
                "units": boundaries,
            }
            with open(ref_dir / f"{speaker_id}.json", "w", encoding="utf-8") as f:
                json.dump(meta, f, ensure_ascii=False, indent=2)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parents[1] / "data")
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--dim", type=int, default=64)
    args = parser.parse_args()
    build_bank(args.out, seed=args.seed, dim=args.dim)
    print(f"Synthetic bank written to {args.out}")


if __name__ == "__main__":
    main()
