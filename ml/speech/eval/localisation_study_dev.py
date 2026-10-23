"""Stage 4 dev study: does localisation flag the right unit? (spliced errors, DEV children only)

There are no labelled real mispronunciations yet, so errors are made by splicing: in a dev child's
reference recording of word W, the audio of unit i is replaced by a unit cut from a DIFFERENT word
(different label, same language) said by another speaker. The spliced attempt is scored against the
bank of W with that child's own references removed (as for a new child), exactly as the service does,
and we check which unit is flagged.

Reported:
  * detection    - share of spliced attempts NOT accepted (needs_remediation)
  * loc_top1     - among detected, the worst-flagged unit is the spliced unit i
  * loc_any      - among detected, unit i is among the flagged units (1-2)
  * clean_accept - unmodified references accepted (sanity check, same LOSO bank)
Unit boundaries are automatic (MMS alignment); splices add sharp joins that real errors do not have.

Usage (from ml/speech):
    python eval/localisation_study_dev.py [--seed 0]
Writes eval/results/localisation_study_dev.{csv,md}.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from src.audio import load_audio  # noqa: E402
from src.bank import ReferenceBank  # noqa: E402
from src.dtw_fast import dtw as fast_dtw  # noqa: E402
from src.embed import make_embedder  # noqa: E402
from src.localise import localise_attempt  # noqa: E402
from src.scoring import score_against_references  # noqa: E402
from src.settings import SPEECH_ROOT, load_settings  # noqa: E402
from src.splits import assert_dev_only  # noqa: E402
from src.threshold import acceptance_range  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument(
        "--children-only", action="store_true", help="drop adult references from every bank"
    )
    args = parser.parse_args()
    rng = np.random.default_rng(args.seed)

    settings = load_settings()
    sc, audio_cfg = settings["scoring"], settings["audio"]
    test_speakers = set(settings["corpus"]["test_speakers"])
    bank = ReferenceBank.from_settings(settings)
    embedder = make_embedder("xlsr", settings)

    def load(word_id, ref_id):
        return load_audio(
            bank.reference_dir / word_id / f"{ref_id}.wav",
            target_sr=audio_cfg["sample_rate"],
            max_duration_s=60,
            trim_top_db=audio_cfg["trim_top_db"],
        )

    # All units of all references, as donor material: (word, language, label, speaker, audio).
    refs_by_word = {w: bank.reference_set(w) for w in bank.words}
    if args.children_only:
        refs_by_word = {
            w: [r for r in v if r["age_group"] != "adult"] for w, v in refs_by_word.items()
        }
    donors = []
    for w, refs in refs_by_word.items():
        for r in refs:
            wav = load(w, r["variant_id"])
            for u in r["units"]:
                a, b = int(u["start_s"] * 16000), int(u["end_s"] * 16000)
                if b - a >= 800:  # >= 50 ms
                    donors.append(
                        (w, bank.words[w]["language"], u["label"], r["speaker"], wav[a:b])
                    )

    rows = []
    for w, refs in refs_by_word.items():
        lang = bank.words[w]["language"]
        queries = [r for r in refs if r["speaker"].startswith("g") and len(r["units"]) >= 2]
        assert_dev_only(
            ["test" if r["speaker"] in test_speakers else "dev" for r in queries],
            "Localisation study",
        )
        for q in queries:
            others = [r for r in refs if r["speaker"] != q["speaker"]]
            if len(others) < 2:
                continue
            rng_ = acceptance_range(
                others,
                k=sc["k_nearest"],
                n_std=sc["n_std"],
                min_refs=sc["min_refs_for_bank_threshold"],
                fallback=sc["fallback_threshold"],
                dtw_fn=fast_dtw,
                loo_unit=sc["loo_unit"],
            )
            wav = load(w, q["variant_id"])

            def assess(audio):
                emb = embedder.embed(audio)
                score, results = score_against_references(
                    emb, others, k=sc["k_nearest"], dtw_fn=fast_dtw
                )
                accepted = score <= rng_.threshold
                segs = []
                if not accepted:
                    by_id = {r["variant_id"]: r for r in others}
                    best = next((x for x in results if by_id[x["variant_id"]]["units"]), None)
                    if best:
                        segs = localise_attempt(
                            emb, by_id[best["variant_id"]], best["path"], settings
                        )
                return accepted, segs

            accepted, _ = assess(wav)
            rows.append(
                {"word": w, "query": q["variant_id"], "kind": "clean", "accepted": accepted}
            )

            for i, u in enumerate(q["units"]):
                pool = [
                    d
                    for d in donors
                    if d[0] != w and d[1] == lang and d[2] != u["label"] and d[3] != q["speaker"]
                ]
                if not pool:
                    continue
                donor = pool[rng.integers(len(pool))]
                a, b = int(u["start_s"] * 16000), int(u["end_s"] * 16000)
                spliced = np.concatenate([wav[:a], donor[4], wav[b:]]).astype(np.float32)
                accepted, segs = assess(spliced)
                flagged = [s for s in segs if s["status"] == "flagged"]
                worst = max(flagged, key=lambda s: s["cost"]) if flagged else None
                rows.append(
                    {
                        "word": w,
                        "query": q["variant_id"],
                        "kind": "spliced",
                        "unit_index": i,
                        "unit": u["label"],
                        "donor": f"{donor[0]}:{donor[2]}",
                        "accepted": accepted,
                        "top1": bool(worst and segs.index(worst) == i),
                        "any": any(segs.index(s) == i for s in flagged),
                        "n_flagged": len(flagged),
                        "error_type": worst["error_type"] if worst else None,
                    }
                )

    df = pd.DataFrame(rows)
    sp, cl = df[df.kind == "spliced"], df[df.kind == "clean"]
    det = sp[~sp.accepted]
    summary = {
        "spliced_attempts": len(sp),
        "detection": float((~sp.accepted).mean()),
        "loc_top1": float(det.top1.mean()),
        "loc_any": float(det["any"].mean()),
        "clean_attempts": len(cl),
        "clean_accept": float(cl.accepted.mean()),
    }
    per_lang = (
        det.assign(language=det.word.map(lambda w: bank.words[w]["language"]))
        .groupby("language")[["top1", "any"]]
        .mean()
    )
    per_word = (
        det.groupby("word")[["top1", "any"]]
        .mean()
        .join(sp.groupby("word").accepted.apply(lambda s: (~s).mean()).rename("detection"))
    )

    out = SPEECH_ROOT / "eval" / "results"
    out.mkdir(parents=True, exist_ok=True)
    stem = "localisation_study_dev" + ("_children_only" if args.children_only else "")
    df.to_csv(out / f"{stem}.csv", index=False)
    md = (
        "# Stage 4 dev study: localisation on spliced errors (DEV children only)\n\n"
        + "\n".join(
            f"- {k}: {v:.3f}" if isinstance(v, float) else f"- {k}: {v}" for k, v in summary.items()
        )
        + "\n\n## By language (detected attempts)\n\n"
        + per_lang.round(3).to_markdown()
        + "\n\n## By word\n\n"
        + per_word.round(3).to_markdown()
        + "\n\n## Error types assigned to the worst flagged unit\n\n"
        + det.error_type.value_counts().to_markdown()
        + "\n"
    )
    (out / f"{stem}.md").write_text(md, encoding="utf-8")
    print(md)


if __name__ == "__main__":
    main()
