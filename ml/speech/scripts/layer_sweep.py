"""Stage 2 layer sweep: which XLS-R layer best separates same-word from different-word, across children?

DEV SPEAKERS ONLY (src/splits.py enforces it). For each word token cut from the child sentence
corpus, one forward pass gives every layer. For each query token we compare (DTW over cosine
frame costs, path-normalised, same as scoring) against:
  * positives: the same word said by OTHER children
  * negatives: N random different words (same language) said by other children
and report per layer:
  * auc  - ROC-AUC of DTW cost separating positives from negatives (higher = better)
  * p_at_1 - share of queries whose lowest-cost candidate is the same word

Word tokens come from automatic MMS alignment (scripts/align_words.py); tokens shorter than
--min-dur or with align_score below --min-align are dropped as unreliable cuts.

Usage (from ml/speech):
    python scripts/layer_sweep.py
Writes eval/results/layer_sweep_dev.csv, layer_sweep_dev.png and layer_sweep_dev.md.
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from sklearn.metrics import roc_auc_score

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.audio import load_audio  # noqa: E402
from src.dtw_fast import dtw_cost  # noqa: E402
from src.scoring import cosine_cost_matrix  # noqa: E402
from src.settings import SPEECH_ROOT, load_settings  # noqa: E402
from src.splits import assert_dev_only  # noqa: E402

PAD_S = 0.03  # context kept either side of an aligned word


def word_key(row) -> str:
    return row.word.lower().strip(".,!?") if row.language == "en" else row.word


def select_tokens(words: pd.DataFrame, min_dur: float, min_align: float) -> pd.DataFrame:
    w = words[(words.split == "dev") & (words.label_ok == 1)].copy()
    w = w[(w.end_s - w.start_s >= min_dur) & (w.align_score >= min_align)]
    w["key"] = [word_key(r) for r in w.itertuples()]
    n_spk = w.groupby(["language", "key"]).speaker_id.transform("nunique")
    w = w[n_spk >= 2].reset_index(drop=True)
    assert_dev_only(w.split, "Layer sweep")
    return w


def build_pairs(w: pd.DataFrame, n_neg: int, seed: int) -> list[tuple[int, int, int]]:
    """(query index, candidate index, is_positive). Same pairs are used for every layer."""
    rng = np.random.default_rng(seed)
    pairs = []
    for q in w.itertuples():
        other = w[(w.speaker_id != q.speaker_id) & (w.language == q.language)]
        pos = other[other.key == q.key].index
        neg = other[other.key != q.key].index
        if len(pos) == 0:
            continue
        neg = rng.choice(neg, size=min(n_neg, len(neg)), replace=False)
        pairs += [(q.Index, int(c), 1) for c in pos] + [(q.Index, int(c), 0) for c in neg]
    return pairs


def embed_all_layers(w: pd.DataFrame, data_dir: Path, utts: pd.DataFrame, model_name: str):
    """{layer: [frames x dim float16 per token]} for layers 1..N, one forward pass per token."""
    from transformers import AutoFeatureExtractor, Wav2Vec2Model

    extractor = AutoFeatureExtractor.from_pretrained(model_name)
    model = Wav2Vec2Model.from_pretrained(model_name).eval()
    n_layers = model.config.num_hidden_layers
    out = {layer: [] for layer in range(1, n_layers + 1)}
    paths = utts.set_index("utt_id").path
    cache_utt, cache_wav = None, None
    for r in w.sort_values("utt_id").itertuples():
        if r.utt_id != cache_utt:
            cache_utt = r.utt_id
            cache_wav = load_audio(data_dir / paths[r.utt_id], max_duration_s=60, trim=False)
        a = max(0, int((r.start_s - PAD_S) * 16000))
        b = min(cache_wav.size, int((r.end_s + PAD_S) * 16000))
        x = extractor(cache_wav[a:b], sampling_rate=16000, return_tensors="pt").input_values
        with torch.inference_mode():
            hs = model(x, output_hidden_states=True).hidden_states
        for layer in out:
            out[layer].append((r.Index, hs[layer][0].numpy().astype(np.float16)))
    return {layer: [e for _, e in sorted(v, key=lambda t: t[0])] for layer, v in out.items()}


def evaluate_layer(embs: list[np.ndarray], pairs, w: pd.DataFrame) -> dict:
    costs = np.array(
        [
            dtw_cost(cosine_cost_matrix(embs[q].astype(np.float32), embs[c].astype(np.float32)))
            for q, c, _ in pairs
        ]
    )
    labels = np.array([p[2] for p in pairs])
    queries = np.array([p[0] for p in pairs])
    res = {"auc": roc_auc_score(labels, -costs)}
    hits = [labels[queries == q][np.argmin(costs[queries == q])] for q in np.unique(queries)]
    res["p_at_1"] = float(np.mean(hits))
    for lang in ("en", "si"):
        m = w.language.values[queries] == lang
        res[f"auc_{lang}"] = roc_auc_score(labels[m], -costs[m])
    return res


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--min-dur", type=float, default=0.12)
    parser.add_argument("--min-align", type=float, default=0.3)
    parser.add_argument("--n-neg", type=int, default=20)
    parser.add_argument("--seed", type=int, default=0)
    args = parser.parse_args()

    settings = load_settings()
    data_dir = settings["paths"]["data_dir"]
    words = pd.read_csv(data_dir / "corpus" / "words.csv")
    utts = pd.read_csv(data_dir / "corpus" / "utterances.csv")
    w = select_tokens(words, args.min_dur, args.min_align)
    pairs = build_pairs(w, args.n_neg, args.seed)
    print(
        f"{len(w)} dev tokens, {w.key.nunique()} word types, {w.speaker_id.nunique()} speakers, "
        f"{len(pairs)} pairs ({sum(p[2] for p in pairs)} positive)"
    )

    t = time.perf_counter()
    layers = embed_all_layers(w, data_dir, utts, settings["embedding"]["model_name"])
    print(f"embedded in {time.perf_counter() - t:.0f}s")

    rows = []
    for layer, embs in layers.items():
        rows.append({"layer": layer, **evaluate_layer(embs, pairs, w)})
        print({k: round(v, 4) if isinstance(v, float) else v for k, v in rows[-1].items()})
    df = pd.DataFrame(rows)

    out_dir = SPEECH_ROOT / "eval" / "results"
    out_dir.mkdir(parents=True, exist_ok=True)
    df.to_csv(out_dir / "layer_sweep_dev.csv", index=False)
    best = df.loc[df.auc.idxmax()]
    (out_dir / "layer_sweep_dev.md").write_text(
        "# Layer sweep (DEV speakers only)\n\n"
        f"- Tokens: {len(w)} ({w.key.nunique()} word types, speakers {sorted(w.speaker_id.unique())})\n"
        f"- Pairs: {len(pairs)} ({sum(p[2] for p in pairs)} same-word across speakers, "
        f"{args.n_neg} random different-word negatives per query)\n"
        f"- Filters: duration >= {args.min_dur}s, align_score >= {args.min_align}\n"
        f"- **Best layer by AUC: {int(best.layer)}** (AUC {best.auc:.3f}, P@1 {best.p_at_1:.3f})\n\n"
        + df.round(4).to_markdown(index=False)
        + "\n",
        encoding="utf-8",
    )
    plot(df, out_dir / "layer_sweep_dev.png")
    print(f"Best layer by AUC: {int(best.layer)}. Results in {out_dir}")


def plot(df: pd.DataFrame, path: Path) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(7, 4))
    for col, label in [
        ("auc", "AUC (all)"),
        ("auc_en", "AUC English"),
        ("auc_si", "AUC Sinhala"),
        ("p_at_1", "P@1"),
    ]:
        ax.plot(df.layer, df[col], marker="o", ms=3, label=label)
    ax.set_xlabel("XLS-R layer")
    ax.set_ylabel("score (dev speakers)")
    ax.set_title("Same-word vs different-word separation across children")
    ax.grid(alpha=0.3)
    ax.legend()
    fig.tight_layout()
    fig.savefig(path, dpi=150)


if __name__ == "__main__":
    main()
