"""Cache embeddings of every aligned word token with the service's embedder (layer + truncation from
config/settings.yaml): data/corpus/emb/<embedder-tag>/<row>.npy, where <row> is the row index
in data/corpus/words.csv. Embedding is not tuning, so test tokens are cached too; evaluation code
decides which split it may read.

Usage (from ml/speech):
    python scripts/embed_corpus_words.py
"""

from __future__ import annotations

import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.audio import load_audio  # noqa: E402
from src.embed import make_embedder  # noqa: E402
from src.settings import load_settings  # noqa: E402

PAD_S = 0.03  # same context as the layer sweep


def emb_dir(settings: dict) -> Path:
    tag = settings["embedding"]["model_name"].split("/")[-1] + f"_l{settings['embedding']['layer']}"
    return settings["paths"]["data_dir"] / "corpus" / "emb" / tag


def main() -> None:
    settings = load_settings()
    data_dir = settings["paths"]["data_dir"]
    words = pd.read_csv(data_dir / "corpus" / "words.csv")
    paths = pd.read_csv(data_dir / "corpus" / "utterances.csv").set_index("utt_id").path
    embedder = make_embedder("xlsr", settings)
    out = emb_dir(settings)
    out.mkdir(parents=True, exist_ok=True)

    t0, cache = time.perf_counter(), (None, None)
    for r in words.sort_values("utt_id").itertuples():
        if cache[0] != r.utt_id:
            cache = (
                r.utt_id,
                load_audio(data_dir / paths[r.utt_id], max_duration_s=60, trim=False),
            )
        wav = cache[1]
        a = max(0, int((r.start_s - PAD_S) * 16000))
        b = min(wav.size, int((r.end_s + PAD_S) * 16000))
        np.save(out / f"{r.Index}.npy", embedder.embed(wav[a:b]).astype(np.float16))
    print(f"{len(words)} tokens -> {out} in {time.perf_counter() - t0:.0f}s ({embedder.name})")


if __name__ == "__main__":
    main()
