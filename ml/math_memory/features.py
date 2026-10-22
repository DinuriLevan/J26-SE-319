"""Feature definitions shared by training and the app.

KEEP IN SYNC WITH app/lib/features/math_memory/ml/next_attempt_features.dart.
The exported model lists `feature_names`; the app refuses to use a model whose
names don't match its own (and falls back to the rules engine).
"""

from __future__ import annotations

# Number Quest: one row per skill asked in a completed attempt.
NQ_FEATURES = [
    "is_baseline",  # 1 for the first (ungraded) attempt
    "ref_level",  # level the next level is chosen relative to
    "mean_level",  # mean level of this skill's questions
    "n_questions",
    "first_try_acc",  # share answered right first time
    "eventual_acc",  # share answered right on either try
    "hint_rate",  # share needing a second try (a hint was shown)
    "mean_rt_s",  # mean time to first answer, seconds (capped at 60)
    "max_miss_streak",  # longest run of not-first-try answers
]
NQ_BASELINE_LEVELS = (1, 2)  # baseline asks each skill at level 1 then 2
NQ_CLASSES = [-1, 0, 1]  # next level = ref_level + class

# Memory Match: one row per completed attempt.
MM_FEATURES = [
    "is_baseline",
    "ref_rung",  # ladder rung the next one is chosen relative to
    "mean_positions",
    "mean_seconds",
    "first_try_acc",
    "eventual_acc",
    "wrong_per_round",  # wrong cards tapped per round
    "mean_rt_s",
    "max_miss_streak",
    "largest_board_first_try_acc",  # first-try accuracy on the biggest boards seen
]
MM_CLASSES = [-3, -2, -1, 0, 1, 2, 3]  # next rung = ref_rung + class

# Difficulty ladder: (pictures, seconds to look). Neighbouring rungs differ in
# exactly one factor, so one step never changes both.
MEMORY_LADDER = [
    (3, 8),
    (3, 7),
    (3, 6),
    (4, 6),
    (4, 5),
    (5, 5),
    (5, 4),
    (6, 4),
    (7, 4),
    (8, 4),
    (9, 4),
]
MEMORY_BASELINE_PLAN = [(3, 6), (3, 6), (4, 6), (4, 6), (5, 6), (5, 6)]
MEMORY_BASELINE_REF_RUNG = 3  # (4 pictures, 6 s): the middle of the baseline
MEMORY_MAX_STEP = {True: 3, False: 2}  # rungs per prediction: baseline / scored

RT_CAP_S = 60.0


def _mean(values):
    values = list(values)
    return sum(values) / len(values) if values else 0.0


def _max_miss_streak(first_try_flags):
    best = run = 0
    for ok in first_try_flags:
        run = 0 if ok else run + 1
        best = max(best, run)
    return best


def number_quest_features(answers, *, start_level: int, is_baseline: bool) -> dict:
    """answers: [{level, correct, tries, rt}] for one skill in one attempt."""
    first = [a["correct"] and a["tries"] == 1 for a in answers]
    ref = max(a["level"] for a in answers) if is_baseline else start_level
    return {
        "is_baseline": 1.0 if is_baseline else 0.0,
        "ref_level": float(ref),
        "mean_level": _mean(a["level"] for a in answers),
        "n_questions": float(len(answers)),
        "first_try_acc": _mean(1.0 if f else 0.0 for f in first),
        "eventual_acc": _mean(1.0 if a["correct"] else 0.0 for a in answers),
        "hint_rate": _mean(1.0 if a["tries"] > 1 else 0.0 for a in answers),
        "mean_rt_s": _mean(min(a["rt"], RT_CAP_S) for a in answers),
        "max_miss_streak": float(_max_miss_streak(first)),
    }


def nearest_rung(positions: int, seconds: int) -> int:
    """Closest ladder rung; a picture counts double a second. Ties → easier."""
    best, best_cost = 0, float("inf")
    for i, (p, s) in enumerate(MEMORY_LADDER):
        cost = 2 * abs(p - positions) + abs(s - seconds)
        if cost < best_cost:
            best, best_cost = i, cost
    return best


def memory_features(rounds, *, is_baseline: bool) -> dict:
    """rounds: [{positions, seconds, correct, tries, rt}] for one attempt."""
    first = [r["correct"] and r["tries"] == 1 for r in rounds]
    largest = max(r["positions"] for r in rounds)
    on_largest = [f for f, r in zip(first, rounds) if r["positions"] == largest]
    ref = (
        MEMORY_BASELINE_REF_RUNG
        if is_baseline
        else nearest_rung(rounds[0]["positions"], rounds[0]["seconds"])
    )
    wrong = [r["tries"] - (1 if r["correct"] else 0) for r in rounds]
    return {
        "is_baseline": 1.0 if is_baseline else 0.0,
        "ref_rung": float(ref),
        "mean_positions": _mean(r["positions"] for r in rounds),
        "mean_seconds": _mean(r["seconds"] for r in rounds),
        "first_try_acc": _mean(1.0 if f else 0.0 for f in first),
        "eventual_acc": _mean(1.0 if r["correct"] else 0.0 for r in rounds),
        "wrong_per_round": _mean(wrong),
        "mean_rt_s": _mean(min(r["rt"], RT_CAP_S) for r in rounds),
        "max_miss_streak": float(_max_miss_streak(first)),
        "largest_board_first_try_acc": _mean(1.0 if f else 0.0 for f in on_largest),
    }
