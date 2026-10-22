"""Adds the target label: how hard is this skill for this child right now?

For each word, look at the SAME child's NEXT 3 words of the SAME skill:
  all right on the first try      -> easy
  2 or more not right first time  -> hard
  otherwise                       -> medium
Rows with fewer than 2 future words of that skill are dropped (not enough
evidence). The label only looks forward, so a row's own result never leaks
into its label.

Usage:  python spell_label.py data/sim_features.csv            -> data/sim_labelled.csv
        python spell_label.py data/pilot_features.csv          -> data/pilot_labelled.csv
"""
from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd

from spell_common import banner_for, read_features_csv, write_csv_with_banner

LOOK_AHEAD = 3
MIN_FUTURE = 2


def label(df: pd.DataFrame) -> pd.DataFrame:
    df = df.sort_values(["childId", "roundNo", "wordIndex"], kind="stable").reset_index(drop=True)
    labels = [None] * len(df)
    future_n = [0] * len(df)
    for _, idx in df.groupby(["childId", "phonics_skill"], sort=False).groups.items():
        idx = list(idx)
        ok = df.loc[idx, "correct_first_try"].tolist()
        for k, i in enumerate(idx):
            nxt = ok[k + 1:k + 1 + LOOK_AHEAD]
            future_n[i] = len(nxt)
            if len(nxt) < MIN_FUTURE:
                continue
            failed = sum(1 for v in nxt if not v)
            labels[i] = "easy" if failed == 0 else ("hard" if failed >= 2 else "medium")
    df["future_words"] = future_n
    df["label"] = labels
    return df[df["label"].notna()].reset_index(drop=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("features_csv")
    ap.add_argument("--out")
    args = ap.parse_args()
    src = Path(args.features_csv)
    out = Path(args.out) if args.out else src.with_name(src.name.replace("_features", "_labelled"))
    df = label(read_features_csv(src))
    write_csv_with_banner(df, out, banner_for(src))
    print(f"{out.name}: {len(df)} labelled rows; {df['label'].value_counts().to_dict()}")


if __name__ == "__main__":
    main()
