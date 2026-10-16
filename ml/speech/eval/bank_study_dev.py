"""Stage 3 dev study: multi-reference bank + learned range vs a single-reference baseline.

DEV SPEAKERS ONLY (src/splits.py enforces it). Word tokens come from the child sentence corpus.
For each query token q (child s, word W), the references are tokens of a word from OTHER children:
  * correct trial: q against the bank of W            -> should be accepted
  * wrong trials:  q against the bank of another word W' (q is then the "wrong word" for W')
      - random:    up to --n-random random words of the same language
      - near-miss: up to --n-near words whose romanised form is closest to W (edit distance <= 0.5),
                   a rough stand-in for mispronunciations, which the corpus does not label
Systems:
  * single_fallback : first reference only (by speaker id), fixed fallback threshold from config
  * single_devbest  : first reference only, global threshold chosen to maximise balanced accuracy
                      on these same dev trials (optimistic, in-sample baseline)
  * bank_learned    : all references, mean of k nearest, range learned from the bank (LOO
                      mean + n*std); words with < min_refs references use the dev-best threshold
Reported for all trials and for the "bank regime" (trials whose bank has >= min_refs references,
where the learned range actually operates). Also recommends a dev-chosen fallback threshold.

Usage (from ml/speech):
    python eval/bank_study_dev.py
Writes eval/results/bank_study_dev.{csv,md}.
"""

from __future__ import annotations

import argparse
import sys
from functools import lru_cache
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "eval"))
from embed_corpus_words import emb_dir  # noqa: E402
from layer_sweep import select_tokens  # noqa: E402
from metrics import balanced_accuracy, best_global_threshold, normalised_edit_distance  # noqa: E402

from src.dtw_fast import dtw_cost  # noqa: E402
from src.scoring import cosine_cost_matrix  # noqa: E402
from src.settings import SPEECH_ROOT, load_settings  # noqa: E402
from src.splits import assert_dev_only  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--n-random", type=int, default=5)
    parser.add_argument("--n-near", type=int, default=3)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument(
        "--loo",
        choices=["token", "speaker"],
        default="token",
        help="token = spec (leave one reference out); speaker = leave out all of that child's refs",
    )
    args = parser.parse_args()

    settings = load_settings()
    sc = settings["scoring"]
    k, n_std, min_refs = sc["k_nearest"], sc["n_std"], sc["min_refs_for_bank_threshold"]
    data_dir = settings["paths"]["data_dir"]
    w = select_tokens(pd.read_csv(data_dir / "corpus" / "words.csv"), 0.12, 0.3)
    assert_dev_only(w.split, "Bank study")
    edir = emb_dir(settings)
    # select_tokens resets the index; keep the words.csv row to find the cached embedding.
    rows = pd.read_csv(data_dir / "corpus" / "words.csv")
    rows["key"] = [
        r.word.lower().strip(".,!?") if r.language == "en" else r.word for r in rows.itertuples()
    ]
    w = w.merge(
        rows.reset_index()[["index", "utt_id", "word_index"]], on=["utt_id", "word_index"]
    ).rename(columns={"index": "row"})
    emb = {r: np.load(edir / f"{r}.npy").astype(np.float32) for r in w.row}

    @lru_cache(maxsize=None)
    def cost(a: int, b: int) -> float:
        return dtw_cost(cosine_cost_matrix(emb[a], emb[b]))

    speaker_of = dict(zip(w.row, w.speaker_id))
    roman = w.groupby(["language", "key"]).roman.first().to_dict()

    def bank_rows(language, key, exclude_speaker):
        m = (w.language == language) & (w.key == key) & (w.speaker_id != exclude_speaker)
        return tuple(w[m].sort_values(["speaker_id", "row"]).row)

    @lru_cache(maxsize=None)
    def learned_threshold(refs: tuple) -> float | None:
        if len(refs) < min_refs:
            return None
        loo = []
        for r in refs:
            if args.loo == "speaker":
                others = [o for o in refs if speaker_of[o] != speaker_of[r]]
            else:
                others = [o for o in refs if o != r]
            if others:
                kk = max(1, min(k, len(others)))
                loo.append(np.mean(sorted(cost(r, o) for o in others)[:kk]))
        if len(loo) < min_refs:
            return None
        # token mode is the same as src.threshold.leave_one_out_scores, via cached costs
        return float(np.mean(loo) + n_std * np.std(loo))

    rng = np.random.default_rng(args.seed)
    trials = []
    for q in w.itertuples():
        same_lang = w[(w.language == q.language) & (w.speaker_id != q.speaker_id)]
        others = sorted(set(same_lang.key) - {q.key})
        near = sorted(
            (normalised_edit_distance(roman[(q.language, q.key)], roman[(q.language, o)]), o)
            for o in others
        )
        near = [o for d, o in near if d <= 0.5][: args.n_near]
        rand = list(rng.choice(others, size=min(args.n_random, len(others)), replace=False))
        for kind, keys in [("correct", [q.key]), ("random", rand), ("near_miss", near)]:
            for key in keys:
                refs = bank_rows(q.language, key, q.speaker_id)
                if not refs:
                    continue
                costs = sorted(cost(q.row, r) for r in refs)
                trials.append(
                    {
                        "query_row": q.row,
                        "speaker_id": q.speaker_id,
                        "language": q.language,
                        "target": key,
                        "kind": kind,
                        "label_ok": kind == "correct",
                        "n_refs": len(refs),
                        "single_score": cost(q.row, refs[0]),
                        "bank_score": float(np.mean(costs[:k])),
                        "learned_threshold": learned_threshold(refs),
                    }
                )
    t = pd.DataFrame(trials)

    devbest = best_global_threshold(t.single_score, t.label_ok)
    t["single_fallback"] = t.single_score <= sc["fallback_threshold"]
    t["single_devbest"] = t.single_score <= devbest
    thr = t.learned_threshold.fillna(devbest)
    t["bank_learned"] = t.bank_score <= thr

    systems = ["single_fallback", "single_devbest", "bank_learned"]
    out_rows = []
    for subset, m in [
        ("all", t.n_refs >= 1),
        (f"bank regime (>= {min_refs} refs)", t.n_refs >= min_refs),
    ]:
        for neg in ["random", "near_miss"]:
            sel = m & ((t.kind == "correct") | (t.kind == neg))
            for lang in ["all", "en", "si"]:
                s2 = sel if lang == "all" else sel & (t.language == lang)
                for sys_name in systems:
                    out_rows.append(
                        {
                            "subset": subset,
                            "negatives": neg,
                            "language": lang,
                            "system": sys_name,
                            **balanced_accuracy(t[sys_name][s2], t.label_ok[s2]),
                        }
                    )
    res = pd.DataFrame(out_rows)

    out_dir = SPEECH_ROOT / "eval" / "results"
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = "bank_study_dev" if args.loo == "token" else "bank_study_dev_loso"
    res.to_csv(out_dir / f"{stem}.csv", index=False)
    head = res[res.language == "all"].pivot_table(
        index=["subset", "negatives"], columns="system", values="balanced_accuracy"
    )
    learned = t.learned_threshold.dropna()
    md = (
        "# Stage 3 dev study: multi-reference bank vs single reference\n\n"
        f"- Dev speakers: {sorted(w.speaker_id.unique())}; {len(w)} query tokens; "
        f"{len(t)} trials ({int(t.label_ok.sum())} correct, {int((~t.label_ok).sum())} wrong)\n"
        f"- Leave-one-out unit: {args.loo}\n"
        f"- k = {k}, n_std = {n_std}, min_refs = {min_refs}; config fallback = {sc['fallback_threshold']}\n"
        f"- Trials in the bank regime (>= {min_refs} refs): {int((t.n_refs >= min_refs).sum())} "
        f"({(t.n_refs >= min_refs).mean():.0%}); learned thresholds: median {learned.median():.3f}, "
        f"range {learned.min():.3f}-{learned.max():.3f}\n"
        f"- **Dev-best global threshold for a single reference: {devbest:.3f}** "
        "(recommended fallback_threshold)\n\n"
        "## Balanced accuracy (all languages)\n\n"
        + head.round(3).to_markdown()
        + "\n\n## Full table\n\n"
        + res.round(3).to_markdown(index=False)
        + "\n"
    )
    (out_dir / f"{stem}.md").write_text(md, encoding="utf-8")
    print(head.round(3).to_string())
    print(
        f"dev-best single threshold {devbest:.3f}; bank-regime trials {(t.n_refs >= min_refs).sum()}"
    )


if __name__ == "__main__":
    main()
