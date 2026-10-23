"""Shows what the difficulty classifier currently thinks about each child.

Input: the app's model state export (Teacher View → ⋮ menu →
Model state (JSON); file spelling_model_<date>.json in
Android/data/com.akurin.akurin/files/spelling_exports/).

Prints, per child and per sound: the classifier's latest label, how sure it is,
whether it came from the trained model ("ml") or the fallback rule, how many
predictions are kept (up to 3, averaged by the app), and the BKT know-it chance.
With --csv it also saves the table.

Usage:  python spell_predictions.py spelling_model_2026-10-16T21-30-00.json [--csv predictions.csv]
"""
from __future__ import annotations

import argparse
import json
import sys

import pandas as pd

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("model_json")
    ap.add_argument("--csv")
    args = ap.parse_args()

    state = json.load(open(args.model_json, encoding="utf-8"))
    rows = []
    for c in state["children"]:
        who = f"{c['avatar']} {c.get('name') or ''}".strip()
        preds = c.get("predictions", {})
        print(f"\n{who}  (child {c['childId'][:8]}, {len(c['rounds'])} rounds, group {c.get('group', 'adaptive')})")
        if not preds:
            print("  no classifier predictions yet (plays after the update will add them)")
            continue
        print(f"  {'sound':22} {'says':7} {'sure':>5}  {'source':8} {'kept':>4}  {'BKT':>5}")
        for skill, ps in preds.items():
            latest = ps[-1]
            sure = latest["probs"][latest["label"]]
            bkt = c["skills"][skill]["pL"]
            print(f"  {skill:22} {latest['label']:7} {sure:5.0%}  {latest['source']:8} {len(ps):>4}  {bkt:5.2f}")
            rows.append({
                "child": who, "childId": c["childId"], "skill": skill, "label": latest["label"],
                "confidence": round(sure, 3), "source": latest["source"], "predictions_kept": len(ps),
                "bkt_mastery": round(bkt, 3), **{f"p_{k}": round(v, 3) for k, v in latest["probs"].items()},
                "at": latest["at"],
            })
    if args.csv and rows:
        pd.DataFrame(rows).to_csv(args.csv, index=False)
        print(f"\nsaved {args.csv}")


if __name__ == "__main__":
    main()
