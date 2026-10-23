"""Precompute reference embeddings: data/reference/<word_id>/<speaker_id>.wav -> data/embeddings/...npy

Every .wav needs a sibling <speaker_id>.json, for example:
    {"speaker_id": "spk_adult_01", "age_group": "adult", "accent": "standard",
     "units": [{"label": "ක", "start_s": 0.00, "end_s": 0.18}, ...]}
("units" may be [] until boundaries are annotated in Audacity/Praat; Stage 4 needs them.)

Writes data/embeddings/manifest.json recording the embedder, so the service can refuse to
score against embeddings from a different model or layer. Rebuilds everything each run.

Usage (from ml/speech):
    python scripts/build_embeddings.py [--embedder xlsr|spectral]
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.audio import load_audio  # noqa: E402
from src.bank import MANIFEST  # noqa: E402
from src.embed import make_embedder  # noqa: E402
from src.settings import DEFAULT_SETTINGS, load_settings  # noqa: E402


def build(settings: dict, embedder) -> int:
    ref_dir, emb_dir = settings["paths"]["reference_dir"], settings["paths"]["embeddings_dir"]
    wavs = sorted(Path(ref_dir).glob("*/*.wav"))
    missing = [w for w in wavs if not w.with_suffix(".json").exists()]
    if missing:
        raise SystemExit("Missing metadata json for:\n  " + "\n  ".join(map(str, missing)))

    if Path(emb_dir).exists():
        shutil.rmtree(emb_dir)
    for wav_path in wavs:
        wav = load_audio(
            wav_path,
            target_sr=settings["audio"]["sample_rate"],
            max_duration_s=settings["audio"]["max_duration_s"],
            trim_top_db=settings["audio"]["trim_top_db"],
        )
        out = Path(emb_dir) / wav_path.parent.name / f"{wav_path.stem}.npy"
        out.parent.mkdir(parents=True, exist_ok=True)
        emb = embedder.embed(wav)
        np.save(out, emb)
        print(f"{wav_path.parent.name}/{wav_path.stem}: {emb.shape}")

    Path(emb_dir).mkdir(parents=True, exist_ok=True)
    (Path(emb_dir) / MANIFEST).write_text(
        json.dumps({"embedder": embedder.name, "count": len(wavs)}), encoding="utf-8"
    )
    return len(wavs)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--embedder", default="xlsr", choices=["xlsr", "spectral"])
    parser.add_argument("--settings", default=DEFAULT_SETTINGS)
    args = parser.parse_args()
    settings = load_settings(args.settings)
    n = build(settings, make_embedder(args.embedder, settings))
    print(f"Built {n} reference embeddings.")


if __name__ == "__main__":
    main()
