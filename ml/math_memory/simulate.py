"""Synthetic learner simulator for the Math & Memory next-attempt models.

THIS IS SYNTHETIC, EXPERT-AUTHORED DATA, NOT REAL LEARNER DATA.

Each simulated child has hidden abilities. We simulate the attempts they would
play in the app, compute exactly the features the app computes after an attempt
(see `features.py` and `app/lib/features/math_memory/ml/next_attempt_features.dart`),
and label each attempt with the configuration an expert policy would pick if it
could see the hidden ability:

    "the hardest setting where the child would still get about 70% right on the
     first try" — the zone where practice is challenging but achievable —
    limited to a small step from the current setting, so difficulty never jumps.

A model trained on these rows learns to infer that target from the noisy,
observable performance of a single attempt. Its accuracy on real children is
unknown until it is re-trained / validated on real (anonymised) attempts.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np

from features import (
    MEMORY_LADDER,
    MEMORY_BASELINE_PLAN,
    NQ_BASELINE_LEVELS,
    memory_features,
    nearest_rung,
    number_quest_features,
)

TARGET_FIRST_TRY = 0.70  # the "about 70% right first time" zone


def sigmoid(x: float) -> float:
    return 1.0 / (1.0 + math.exp(-x))


# --------------------------------------------------------------------------
# Number Quest
# --------------------------------------------------------------------------

SKILLS = ["counting", "addition", "subtraction", "multiplication", "division"]
# Typical relative difficulty for 7-9 year olds (in level units).
SKILL_OFFSET = {
    "counting": 1.0,
    "addition": 0.4,
    "subtraction": 0.0,
    "multiplication": -0.6,
    "division": -0.9,
}


@dataclass
class NqLearner:
    ability: dict[str, float]  # hidden level the child is comfortable at
    base_rt: float  # seconds for an easy question
    slope: float  # how sharply success falls off above their ability

    def p_first(self, skill: str, level: int) -> float:
        return sigmoid(self.slope * (self.ability[skill] - level + 0.5))

    def ideal_level(self, skill: str) -> int:
        best = 1
        for level in range(1, 6):
            if self.p_first(skill, level) >= TARGET_FIRST_TRY:
                best = level
        return best


def random_nq_learner(rng: np.random.Generator) -> NqLearner:
    general = rng.uniform(0.3, 5.5)
    return NqLearner(
        ability={s: general + SKILL_OFFSET[s] + rng.normal(0, 0.7) for s in SKILLS},
        base_rt=rng.uniform(3.0, 10.0),
        slope=rng.uniform(1.2, 2.4),
    )


def answer(rng, p_first: float, base_rt: float, level: int, ability: float):
    """One multiple-choice question with up to two tries (as in the app)."""
    rt = base_rt * math.exp(0.3 * (level - ability)) * rng.lognormal(0, 0.35)
    rt = float(min(rt, 90.0))
    if rng.random() < p_first:
        return {"correct": True, "tries": 1, "rt": rt}
    # After a hint, one of two remaining choices; knowledge still helps.
    p_second = 0.5 + 0.4 * p_first
    return {"correct": bool(rng.random() < p_second), "tries": 2, "rt": rt}


def simulate_nq_skill_attempt(rng, learner: NqLearner, skill: str, baseline: bool, start_level: int):
    if baseline:
        levels = list(NQ_BASELINE_LEVELS)
    else:
        # Scored attempts ask each skill 1-3 times; in-attempt rules may move
        # the level by one, which we mimic with a small random drift.
        n = int(rng.choice([1, 2, 2, 2, 3]))
        levels, level = [], start_level
        for _ in range(n):
            levels.append(level)
            if rng.random() < 0.15:
                level = int(np.clip(level + rng.choice([-1, 1]), 1, 5))
    answers = []
    for level in levels:
        a = answer(rng, learner.p_first(skill, level), learner.base_rt, level, learner.ability[skill])
        a["level"] = level
        answers.append(a)
    return answers


def nq_label(learner: NqLearner, skill: str, ref_level: int) -> int:
    """Expert policy: ideal level, at most one step from the reference level."""
    ideal = learner.ideal_level(skill)
    target = int(np.clip(ideal, ref_level - 1, ref_level + 1))
    target = int(np.clip(target, 1, 5))
    return target - ref_level


def generate_number_quest(n_children: int, seed: int):
    rng = np.random.default_rng(seed)
    rows, labels, groups = [], [], []
    for child in range(n_children):
        learner = random_nq_learner(rng)
        for attempt in range(4):
            baseline = attempt == 0
            for skill in SKILLS:
                start = 1 if baseline else int(rng.integers(1, 6))
                answers = simulate_nq_skill_attempt(rng, learner, skill, baseline, start)
                feats = number_quest_features(answers, start_level=start, is_baseline=baseline)
                rows.append(feats)
                labels.append(nq_label(learner, skill, int(feats["ref_level"])))
                groups.append(child)
    return rows, np.array(labels), np.array(groups)


# --------------------------------------------------------------------------
# Memory Match
# --------------------------------------------------------------------------


@dataclass
class MemoryLearner:
    capacity: float  # pictures recalled at ~50% with 6 s to look
    time_gain: float  # extra capacity per extra second of looking
    base_rt: float
    slope: float

    def p_first(self, positions: int, seconds: int) -> float:
        effective = self.capacity + self.time_gain * (seconds - 6)
        return sigmoid(self.slope * (effective - positions + 0.5))

    def ideal_rung(self) -> int:
        best = 0
        for rung, (p, s) in enumerate(MEMORY_LADDER):
            if self.p_first(p, s) >= TARGET_FIRST_TRY:
                best = rung
        return best


def random_memory_learner(rng) -> MemoryLearner:
    return MemoryLearner(
        capacity=rng.uniform(2.0, 9.5),
        time_gain=rng.uniform(0.1, 0.45),
        base_rt=rng.uniform(1.5, 6.0),
        slope=rng.uniform(1.0, 2.2),
    )


def simulate_memory_attempt(rng, learner: MemoryLearner, baseline: bool, start_rung: int):
    if baseline:
        configs = list(MEMORY_BASELINE_PLAN)
    else:
        configs, rung = [], start_rung
        for _ in range(6):
            configs.append(MEMORY_LADDER[rung])
            if rng.random() < 0.2:
                rung = int(np.clip(rung + rng.choice([-1, 1]), 0, len(MEMORY_LADDER) - 1))
    rounds = []
    for positions, seconds in configs:
        p = learner.p_first(positions, seconds)
        rt = float(min(learner.base_rt * (1 + 0.1 * positions) * rng.lognormal(0, 0.35), 60.0))
        if rng.random() < p:
            rounds.append({"positions": positions, "seconds": seconds, "correct": True, "tries": 1, "rt": rt})
        else:
            # Second guess among the remaining cards, helped a little by memory.
            p_second = min(0.95, 1.0 / max(1, positions - 1) + 0.4 * p)
            rounds.append(
                {"positions": positions, "seconds": seconds, "correct": bool(rng.random() < p_second), "tries": 2, "rt": rt}
            )
    return rounds


def memory_step_limit(baseline: bool) -> int:
    return 3 if baseline else 2


def memory_label(learner: MemoryLearner, ref_rung: int, baseline: bool) -> int:
    limit = memory_step_limit(baseline)
    target = int(np.clip(learner.ideal_rung(), ref_rung - limit, ref_rung + limit))
    target = int(np.clip(target, 0, len(MEMORY_LADDER) - 1))
    return target - ref_rung


def generate_memory_match(n_children: int, seed: int):
    rng = np.random.default_rng(seed)
    rows, labels, groups = [], [], []
    for child in range(n_children):
        learner = random_memory_learner(rng)
        for attempt in range(4):
            baseline = attempt == 0
            start = nearest_rung(*MEMORY_BASELINE_PLAN[0]) if baseline else int(rng.integers(0, len(MEMORY_LADDER)))
            rounds = simulate_memory_attempt(rng, learner, baseline, start)
            feats = memory_features(rounds, is_baseline=baseline)
            rows.append(feats)
            labels.append(memory_label(learner, int(feats["ref_rung"]), baseline))
            groups.append(child)
    return rows, np.array(labels), np.array(groups)
