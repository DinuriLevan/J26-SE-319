"""Export a random sample of aligned word clips so a person can listen and check the cuts.

Writes data/corpus/spotcheck/NN_<speaker>_<roman>.wav (gitignored) and spotcheck.csv, with a blank
`cut_ok` column to fill in (1 = clean word, 0 = clipped/includes neighbour/wrong word).

Usage (from ml/speech):
    python scripts/export_spotcheck.py [--n 30] [--seed 0]
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import pandas as pd
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.audio import load_audio  # noqa: E402
from src.settings import load_settings  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=30)
    parser.add_argument("--seed", type=int, default=0)
    args = parser.parse_args()

    data_dir = load_settings()["paths"]["data_dir"]
    words = pd.read_csv(data_dir / "corpus" / "words.csv")
    paths = pd.read_csv(data_dir / "corpus" / "utterances.csv").set_index("utt_id").path
    sample = words.sample(args.n, random_state=args.seed).reset_index(drop=True)

    out = data_dir / "corpus" / "spotcheck"
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    files = []
    for i, r in sample.iterrows():
        wav = load_audio(data_dir / paths[r.utt_id], max_duration_s=60, trim=False)
        clip = wav[int(r.start_s * 16000) : int(r.end_s * 16000)]
        name = f"{i:02d}_{r.speaker_id}_{r.roman}.wav"
        sf.write(out / name, clip, 16000)
        files.append(name)
    sample.assign(file=files, cut_ok="").to_csv(out / "spotcheck.csv", index=False)
    print(f"{len(sample)} clips in {out}")


if __name__ == "__main__":
    main()
