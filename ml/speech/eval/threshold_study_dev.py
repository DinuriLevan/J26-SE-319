"""Accuracy study (dev only): one shared pass mark per language vs the per-word learned range.

DEV SPEAKERS ONLY (src/splits.py enforces it). Probes are every child in the reference bank
(corpus dev children cut from sentences, plus the field-recorded children); adults are references
only. Leave-one-child-out: for held-out child c, every word's bank drops all of c's references and
each of c's clips is scored (mean of the k nearest DTW costs, as in the service) against
  * its own word's bank          -> a correct attempt (should be accepted)
  * every other word's bank      -> a wrong word (should be rejected)
in the same language.

Pass-mark rules compared:
  * per_word : the current learned range (leave-one-speaker-out mean + n_std * std, fallback < min_refs)
  * shared   : one threshold per language = the (1 - target_frr) quantile of correct-attempt scores,
               i.e. at most target_frr of correct attempts get "try again" (owner choice
               2026-10-20: fewer false "try again" matters more than a few wrong words accepted).
The shared threshold is chosen from children recorded saying SINGLE WORDS (source field_recording),
because that is what the app hears; words cut from sentences score lower (closer to each other) and
would set the pass mark too strict for real use. It is evaluated NESTED (the threshold for child c
is chosen without c), so the reported rates are not in-sample; the threshold written for the
service is then chosen from all single-word dev children.

Usage (from ml/speech):
    python eval/threshold_study_dev.py [--target-frr 0.10]
Writes eval/results/threshold_study_dev.{md,json}.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from src.bank import ReferenceBank  # noqa: E402
from src.dtw_fast import dtw as fast_dtw  # noqa: E402
from src.scoring import score_against_references  # noqa: E402
from src.settings import load_settings  # noqa: E402
from src.splits import assert_dev_only  # noqa: E402
from src.threshold import acceptance_range  # noqa: E402

OUT = ROOT / "eval" / "results"


def shared_threshold(correct_scores: list[float], target_frr: float) -> float:
    """Smallest pass mark that rejects at most target_frr of correct attempts."""
    return float(np.quantile(np.asarray(correct_scores), 1 - target_frr, method="higher"))


def rates(rows: list[tuple[str, str, float]], thr) -> tuple[float, float]:
    """(false-rejection rate, false-acceptance rate) for rows (true word, bank word, score)."""
    ok = [s > thr(v) for w, v, s in rows if w == v]
    bad = [s <= thr(v) for w, v, s in rows if w != v]
    return float(np.mean(ok)), float(np.mean(bad))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target-frr", type=float, default=0.10)
    args = parser.parse_args()

    settings = load_settings()
    sc = settings["scoring"]
    test_speakers = set(settings["corpus"]["test_speakers"])
    bank = ReferenceBank.from_settings(settings)
    k = sc["k_nearest"]

    def learned(refs):
        return acceptance_range(
            refs, k, sc["n_std"], sc["min_refs_for_bank_threshold"], sc["fallback_threshold"],
            fast_dtw, sc.get("loo_unit", "token"),
        ).threshold

    report, result = [], {"target_frr": args.target_frr, "k": k, "languages": {}}
    for lang in ("si", "en"):
        words = [w for w, r in bank.words.items() if r["language"] == lang]
        refs = {w: bank.reference_set(w) for w in words}
        children = sorted(
            {r["speaker"] for w in words for r in refs[w] if r["age_group"] == "child"}
        )
        assert_dev_only(["test" if c in test_speakers else "dev" for c in children], "Pass mark")
        single_word = sorted(
            {
                m["speaker_id"]
                for w in words
                for m in bank.references(w)
                if m.get("source") == "field_recording" and m["speaker_id"] in children
            }
        )

        rows: dict[str, list] = {}
        per_word_thr: dict[str, dict] = {}
        for c in children:
            banks = {w: [r for r in refs[w] if r["speaker"] != c] for w in words}
            per_word_thr[c] = {w: learned(banks[w]) for w in words}
            rows[c] = [
                (w, v, score_against_references(clip["emb"], banks[v], k=k, dtw_fn=fast_dtw)[0])
                for w in words
                for clip in refs[w]
                if clip["speaker"] == c
                for v in words
                if banks[v]
            ]

        def pooled(rule):
            fr, fa, n_ok, n_bad = [], [], 0, 0
            for c in children:
                r_fr, r_fa = rates(rows[c], rule(c))
                ok = sum(w == v for w, v, _ in rows[c])
                fr.append(r_fr * ok)
                fa.append(r_fa * (len(rows[c]) - ok))
                n_ok, n_bad = n_ok + ok, n_bad + len(rows[c]) - ok
            return sum(fr) / n_ok, sum(fa) / n_bad, n_ok, n_bad

        def nested_shared(c):
            pos = [s for o in single_word if o != c for w, v, s in rows[o] if w == v]
            t = shared_threshold(pos, args.target_frr)
            return lambda v: t

        all_pos = [s for c in single_word for w, v, s in rows[c] if w == v]
        final = shared_threshold(all_pos, args.target_frr)

        def pooled_over(group, rule):
            nonlocal children
            saved, children = children, group
            try:
                return pooled(rule)
            finally:
                children = saved

        pw = pooled(lambda c: per_word_thr[c].__getitem__)
        sh = pooled(nested_shared)
        pw_sw = pooled_over(single_word, lambda c: per_word_thr[c].__getitem__)
        sh_sw = pooled_over(single_word, nested_shared)
        per_child = {
            c: {"per_word": rates(rows[c], per_word_thr[c].__getitem__),
                "shared": rates(rows[c], nested_shared(c))}
            for c in children
        }
        result["languages"][lang] = {
            "children": children,
            "n_correct": pw[2],
            "n_wrong": pw[3],
            "single_word_children": single_word,
            "per_word": {"frr": pw[0], "far": pw[1]},
            "shared_nested": {"frr": sh[0], "far": sh[1]},
            "single_word_per_word": {"frr": pw_sw[0], "far": pw_sw[1]},
            "single_word_shared_nested": {"frr": sh_sw[0], "far": sh_sw[1]},
            "shared_threshold": round(final, 4),
            "per_child": per_child,
        }
        report += [
            f"## {lang}",
            "",
            f"Children (held out one at a time): {', '.join(children)}. "
            f"{pw[2]} correct attempts, {pw[3]} wrong-word trials.",
            "",
            f"**Single-word children ({', '.join(single_word)}), what the app hears:**",
            "",
            "| Pass mark | Correct words rejected | Wrong words accepted |",
            "|---|---|---|",
            f"| per word, learned range (before) | {pw_sw[0]:.1%} | {pw_sw[1]:.1%} |",
            f"| shared, nested (chosen on the other child) | {sh_sw[0]:.1%} | {sh_sw[1]:.1%} |",
            "",
            "**All dev children** (sentence-cut children included, for context):",
            "",
            "| Pass mark | Correct words rejected | Wrong words accepted |",
            "|---|---|---|",
            f"| per word, learned range (before) | {pw[0]:.1%} | {pw[1]:.1%} |",
            f"| shared, nested | {sh[0]:.1%} | {sh[1]:.1%} |",
            "",
            f"Shared pass mark for the service (all single-word dev children): **{final:.4f}**",
            "",
            "| Child | per word: rejected / accepted | shared: rejected / accepted |",
            "|---|---|---|",
            *[
                f"| {c} | {v['per_word'][0]:.0%} / {v['per_word'][1]:.1%} "
                f"| {v['shared'][0]:.0%} / {v['shared'][1]:.1%} |"
                for c, v in per_child.items()
            ],
            "",
        ]

    OUT.mkdir(parents=True, exist_ok=True)
    head = [
        "# Pass-mark study (dev only)",
        "",
        f"Generated by `eval/threshold_study_dev.py --target-frr {args.target_frr}`. "
        f"k = {k}. \"Wrong words\" are other practice words, which are easier to reject than real "
        "mispronunciations, so the accepted rate for real mispronunciations will be higher.",
        "",
    ]
    (OUT / "threshold_study_dev.md").write_text("\n".join(head + report), encoding="utf-8")
    (OUT / "threshold_study_dev.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print("\n".join(head + report))


if __name__ == "__main__":
    main()
