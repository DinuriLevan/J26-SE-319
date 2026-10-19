"""The two feature sets, described as data so the app can rebuild them exactly.

A (correctness only): final_correct, correct_first_try, attempts, error-type
  counts, edit_distance, skill (one-hot), skill_stage, difficulty, word
  length, has_bdpq, bkt_mastery_before (the app's P(L) before this word).
B (A + behaviour): A + hesitation_ratio, pause_ratio, log first_input_ms,
  log total_ms, corrections, motor_slips, replays, n_insertions, n_deletions,
  n_replacements, n_reorders, distractor_picks, answer_length_diff.

Each feature is a recipe: {"name", "kind", "source", ...}. Kinds:
  bool      1 if the column is true, else 0
  num       the number (optionally clipped to [lo, hi])
  log1p     log(1 + max(0, value))
  onehot    1 if the column equals "value"
  length    number of letters in the word
  has_bdpq  1 if the word contains b, d, p or q
Sinhala (--lang si, si_recipes): Sinhala mistake types (pilla missing / wrong /
short-long, hal, look-alike letter, …) and n_aksharas / n_marks instead of
word_length / has_bdpq. spell_export.py writes this list to preprocessing.json; the Dart side
(difficulty_classifier.dart) applies the same recipes in the same order.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from spell_common import ERROR_TYPES, SI_ERROR_TYPES, load_word_bank, si_skill_order, skill_order

BEHAVIOUR = [
    {"name": "hesitation_ratio", "kind": "num", "source": "hesitation_ratio", "clip": [0, 10]},
    {"name": "pause_ratio", "kind": "num", "source": "pause_ratio", "clip": [0, 10]},
    {"name": "log_first_input_ms", "kind": "log1p", "source": "first_input_ms"},
    {"name": "log_total_ms", "kind": "log1p", "source": "total_ms"},
    *({"name": c, "kind": "num", "source": c} for c in [
        "corrections", "motor_slips", "replays", "n_insertions", "n_deletions", "n_replacements",
        "n_reorders", "distractor_picks", "answer_length_diff",
    ]),
]


def si_recipes(feature_set: str, skills: list[str] | None = None) -> list[dict]:
    """Sinhala: the same idea with Sinhala mistake types, and the word's size in
    aksharas and pillas (instead of letters and b/d/p/q)."""
    skills = skills or si_skill_order()
    a = [
        {"name": "final_correct", "kind": "bool", "source": "final_correct"},
        {"name": "correct_first_try", "kind": "bool", "source": "correct_first_try"},
        {"name": "attempts", "kind": "num", "source": "attempts"},
        *({"name": t, "kind": "num", "source": t} for t in SI_ERROR_TYPES),
        {"name": "edit_distance", "kind": "num", "source": "edit_distance"},
        *({"name": f"skill={s}", "kind": "onehot", "source": "phonics_skill", "value": s} for s in skills),
        {"name": "skill_stage", "kind": "num", "source": "skill_stage"},
        {"name": "difficulty", "kind": "num", "source": "difficulty"},
        {"name": "n_aksharas", "kind": "num", "source": "n_aksharas"},
        {"name": "n_marks", "kind": "num", "source": "n_marks"},
        {"name": "bkt_mastery_before", "kind": "num", "source": "p_before", "default": 0.1},
    ]
    if feature_set == "A":
        return a
    if feature_set == "B":
        return a + [dict(r) for r in BEHAVIOUR]
    raise ValueError(f"unknown feature set {feature_set!r}")


def recipes(feature_set: str, skills: list[str] | None = None, lang: str = "en") -> list[dict]:
    if lang == "si":
        return si_recipes(feature_set, skills)
    skills = skills or skill_order(load_word_bank())
    a = [
        {"name": "final_correct", "kind": "bool", "source": "final_correct"},
        {"name": "correct_first_try", "kind": "bool", "source": "correct_first_try"},
        {"name": "attempts", "kind": "num", "source": "attempts"},
        *({"name": t, "kind": "num", "source": t} for t in ERROR_TYPES),
        {"name": "edit_distance", "kind": "num", "source": "edit_distance"},
        *({"name": f"skill={s}", "kind": "onehot", "source": "phonics_skill", "value": s} for s in skills),
        {"name": "skill_stage", "kind": "num", "source": "skill_stage"},
        {"name": "difficulty", "kind": "num", "source": "difficulty"},
        {"name": "word_length", "kind": "length", "source": "word"},
        {"name": "has_bdpq", "kind": "has_bdpq", "source": "word"},
        {"name": "bkt_mastery_before", "kind": "num", "source": "p_before", "default": 0.1},
    ]
    if feature_set == "A":
        return a
    if feature_set == "B":
        return a + [dict(r) for r in BEHAVIOUR]
    raise ValueError(f"unknown feature set {feature_set!r}")


def _value(r: dict, row: pd.Series):
    v = row.get(r["source"])
    kind = r["kind"]
    if kind == "bool":
        return 1.0 if (v is True or str(v).strip().lower() == "true") else 0.0
    if kind == "onehot":
        return 1.0 if v == r["value"] else 0.0
    if kind == "length":
        return float(len(str(v)))
    if kind == "has_bdpq":
        return 1.0 if any(c in str(v).lower() for c in "bdpq") else 0.0
    x = r.get("default", 0.0) if v is None or (isinstance(v, float) and np.isnan(v)) else float(v)
    if kind == "log1p":
        return float(np.log1p(max(0.0, x)))
    if "clip" in r:
        x = float(min(max(x, r["clip"][0]), r["clip"][1]))
    return x


def build_matrix(df: pd.DataFrame, rs: list[dict]) -> np.ndarray:
    """Vectorised version of the recipes (same result as applying _value)."""
    cols = []
    for r in rs:
        src = df[r["source"]]
        kind = r["kind"]
        if kind == "bool":
            col = src.map(lambda v: v is True or str(v).strip().lower() == "true").astype(float)
        elif kind == "onehot":
            col = (src == r["value"]).astype(float)
        elif kind == "length":
            col = src.astype(str).str.len().astype(float)
        elif kind == "has_bdpq":
            col = src.astype(str).str.lower().str.contains("[bdpq]").astype(float)
        else:
            col = pd.to_numeric(src, errors="coerce").fillna(r.get("default", 0.0)).astype(float)
            if kind == "log1p":
                col = np.log1p(col.clip(lower=0))
            elif "clip" in r:
                col = col.clip(r["clip"][0], r["clip"][1])
        cols.append(col.to_numpy())
    return np.column_stack(cols)


def build_row(row: pd.Series, rs: list[dict]) -> list[float]:
    return [_value(r, row) for r in rs]
