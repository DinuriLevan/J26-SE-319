"""Simulated Sinhala children, in the SAME format as the app's Sinhala features CSV.

Each child has:
  - 1-3 hidden weak stages (pilla stages, hal, sanyaka, mahaprana, murdhaja ...): mistakes there are
    likely, and land on the akshara that carries that stage's pilla or letter;
  - maybe a pilla-length habit (ි/ී, ු/ූ, ැ/ෑ, ෙ/ේ, ො/ෝ mixed up), a hal habit (් left out) and a
    look-alike letter habit (බ/භ, ල/ළ, න/ණ ...);
  - a personal speed; and ability that grows a little with every word practised.
Weak stages are slower to start, slower between tiles, more often corrected and replayed.

Mistakes are made like the child builds the word in the app: one akshara is changed (pilla left
out, a different pilla, the short/long form, a look-alike or other letter), or an akshara is left
out, added, or swapped with its neighbour. The error columns follow the app's mistake checker
(sinhala_errors.dart).

Rounds follow the app: round 1 is the 10-word warm-up (placement), then a simple adaptive policy
(most words from the weakest unlocked stage). The BKT estimate before/after each word is computed
exactly as the app does (sinhala_learner.dart), because the model uses it as a feature.

Two data sets:
  data/sim_si_features.csv          behaviour carries a signal (as above)
  data/sim_si_control_features.csv  control: hesitation, corrections, replays, pauses are random
plus the hidden truth (data/sim_si*_truth.csv).

Usage:  python spell_si_simulate.py [--children 200] [--rounds 12] [--seed 11]
"""
from __future__ import annotations

import argparse
import math

import numpy as np
import pandas as pd

from spell_common import (
    DATA, HAL, SI_CONFUSABLE_GROUPS, SI_ERROR_TYPES, SI_FEATURE_COLUMNS, SI_LENGTH_PAIRS, SIM_BANNER,
    compose, load_si_word_bank, median_or_default, si_bkt_update, si_evidence_weight, si_skill_order,
    write_csv_with_banner,
)

MAX_ATTEMPTS = 3
VOWEL_SIGNS = ["ා", "ැ", "ෑ", "ි", "ී", "ු", "ූ", "ෙ", "ේ", "ො", "ෝ"]
COMMON_LETTERS = list("කගචජටඩතදනපබමයරලවසහ")


def confusable_with(letter: str) -> list[str]:
    return [c for g in SI_CONFUSABLE_GROUPS if letter in g for c in g if c != letter]


def vowel_of(marks: list[str]) -> str | None:
    return next((m for m in marks if len(m) == 1 and m not in ("ං", "ඃ")), None)


class Child:
    def __init__(self, cid: str, rng: np.random.Generator, skills: list[str], stage_of: dict):
        self.id, self.rng = cid, rng
        candidates = [s for s in skills if 2 <= stage_of[s] <= 17]
        self.weak = set(rng.choice(candidates, size=int(rng.integers(1, 4)), replace=False).tolist())
        base = float(np.clip(rng.normal(0.86, 0.06), 0.65, 0.97))
        self.ability = {
            s: (float(rng.uniform(0.15, 0.4)) if s in self.weak else float(np.clip(base + rng.normal(0, 0.05), 0.55, 0.98)))
            for s in skills
        }
        self.initial_ability = dict(self.ability)
        self.length_habit = 0.0 if rng.random() < 0.6 else float(rng.uniform(0.2, 0.6))
        self.hal_habit = 0.0 if rng.random() < 0.7 else float(rng.uniform(0.2, 0.5))
        self.lookalike_habit = 0.0 if rng.random() < 0.7 else float(rng.uniform(0.2, 0.5))
        self.speed_ms = float(np.exp(rng.normal(math.log(2200), 0.3)))
        self.gap_ms = float(np.exp(rng.normal(math.log(900), 0.25)))
        self.learning = 0.015
        self.p = {s: 0.1 for s in skills}
        self.unlocked: set[str] = set()
        self.first_inputs: list[float] = []
        self.max_gaps: list[float] = []


def target_index(aks: list[tuple[str, list[str]]], stage: int) -> int:
    """The akshara that carries the word's stage (its pilla / special letter); the
    word bank has no explicit target, so: an akshara with marks for pilla stages,
    else a random one."""
    with_marks = [i for i, (_, m) in enumerate(aks) if m]
    return with_marks[-1] if (with_marks and stage >= 2) else len(aks) - 1


def mutate(aks, child: Child, weak: bool, stage: int, rng) -> tuple[list[tuple[str, list[str]]], str]:
    """One mistake; returns the new akshara list and its error type."""
    aks = [(b, list(m)) for b, m in aks]
    n = len(aks)
    # Habits first: they can hit any word that offers the chance.
    long_short = [i for i, (_, m) in enumerate(aks) if vowel_of(m) in SI_LENGTH_PAIRS]
    if long_short and rng.random() < child.length_habit:
        i = int(rng.choice(long_short))
        v = vowel_of(aks[i][1])
        aks[i] = (aks[i][0], [SI_LENGTH_PAIRS[v] if m == v else m for m in aks[i][1]])
        return aks, "pilla_length"
    hals = [i for i, (_, m) in enumerate(aks) if HAL in m]
    if hals and rng.random() < child.hal_habit:
        i = int(rng.choice(hals))
        aks[i] = (aks[i][0], [m for m in aks[i][1] if m != HAL])
        return aks, "hal"
    alike = [i for i, (b, _) in enumerate(aks) if confusable_with(b)]
    if alike and rng.random() < child.lookalike_habit:
        i = int(rng.choice(alike))
        aks[i] = (str(rng.choice(confusable_with(aks[i][0]))), aks[i][1])
        return aks, "lookalike"

    i = target_index(aks, stage) if weak else int(rng.integers(n))
    base, marks = aks[i]
    roll = rng.random()
    if marks and roll < 0.35:                                   # pilla left out
        v = vowel_of(marks)
        if v == HAL:
            aks[i] = (base, [m for m in marks if m != HAL])
            return aks, "hal"
        aks[i] = (base, [m for m in marks if m != (v or marks[-1])])
        return aks, "pilla_missing"
    if marks and roll < 0.6:                                    # a different / short-long pilla
        v = vowel_of(marks)
        if v in SI_LENGTH_PAIRS and rng.random() < 0.5:
            aks[i] = (base, [SI_LENGTH_PAIRS[v] if m == v else m for m in marks])
            return aks, "pilla_length"
        other = str(rng.choice([x for x in VOWEL_SIGNS if x != v and SI_LENGTH_PAIRS.get(v) != x]))
        aks[i] = (base, [other if m == v else m for m in marks] if v else marks + [other])
        return aks, "pilla_wrong"
    if roll < 0.75 and n > 1:                                   # akshara left out
        del aks[i]
        return aks, "missing"
    if roll < 0.82:                                             # extra akshara
        aks.insert(i, aks[i])
        return aks, "extra"
    if roll < 0.88 and n > 1:                                   # two swapped
        j = i - 1 if i == n - 1 else i + 1
        aks[i], aks[j] = aks[j], aks[i]
        if aks[i] == aks[j]:
            aks[i] = (str(rng.choice(COMMON_LETTERS)), aks[i][1])
            return aks, "other_letter"
        return aks, "order"
    if confusable_with(base) and rng.random() < 0.5:            # a look-alike letter
        aks[i] = (str(rng.choice(confusable_with(base))), marks)
        return aks, "lookalike"
    aks[i] = (str(rng.choice([c for c in COMMON_LETTERS if c != base])), marks)
    return aks, "other_letter"


def play_word(child: Child, word: dict, ctx: dict, control: bool, rng) -> dict:
    skill, stage = word["phonics_skill"], int(word["skill_stage"])
    a = child.ability[skill]
    weak = a < 0.5
    target_aks = word["akshara_list"]
    target = word["word"]

    answers, correct_at, first_error = [], None, None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        p_ok = min(0.98, a + (attempt - 1) * 0.25)
        if rng.random() < p_ok:
            answers.append(target_aks)
            correct_at = attempt
            break
        aks, kind = mutate(target_aks, child, weak, stage, rng)
        if "".join(compose(b, m) for b, m in aks) == target:   # mutation happened to be harmless
            answers.append(target_aks)
            correct_at = attempt
            break
        answers.append(aks)
        first_error = first_error or kind
    attempts = len(answers)
    correct_first = correct_at == 1
    final_correct = correct_at is not None
    first_wrong = next(("".join(compose(b, m) for b, m in x) for x in answers if x is not target_aks), None)
    errors = {t: 0 for t in SI_ERROR_TYPES}
    if first_error:
        errors[first_error] = 1

    slow = (rng.random() < 0.5) if control else weak
    first_input = child.speed_ms * (2.2 if slow else 1.0) * float(np.exp(rng.normal(0, 0.3)))
    mean_gap = child.gap_ms * (1.8 if slow else 1.0) * float(np.exp(rng.normal(0, 0.2)))
    max_gap = mean_gap * float(rng.uniform(1.3, 2.5))
    corrections = int(rng.poisson(0.55 if control else (1.0 if weak else 0.15)))
    motor_slips = int(rng.poisson(0.1))
    replays = int(rng.poisson(0.45 if control else (0.8 if weak else 0.2)))
    paused = float(rng.uniform(2000, 60000)) if rng.random() < 0.01 else 0.0

    n_ak = len(target_aks)
    n_marks = sum(len(m) for _, m in target_aks)
    tiles = n_ak + n_marks
    reorders = int(rng.binomial(corrections, 0.3))
    replacements = int(rng.binomial(corrections - reorders, 0.5))
    deletions = corrections - reorders - replacements
    retyped = 2 * (attempts - 1)                     # tiles put back after a wrong try
    insertions = sum(len(m) + 1 for _, m in answers[0]) + deletions + retyped
    word_tiles = {b for b, _ in target_aks} | {x for _, m in target_aks for x in m}
    used = {b for x in answers for b, _ in x} | {t for x in answers for _, m in x for t in m}
    distractor_picks = len(used - word_tiles) + int(rng.binomial(replacements, 0.3))

    total = first_input + tiles * mean_gap * attempts + corrections * 900 + (attempts - 1) * 2500
    hes = first_input / median_or_default(child.first_inputs)
    pause_ratio = max_gap / median_or_default(child.max_gaps)

    row = {
        **ctx,
        "word_id": word["word_id"], "word": target, "phonics_skill": skill,
        "skill_stage": stage, "difficulty": int(word["difficulty"]),
        "first_input_ms": round(first_input, 1), "total_ms": round(total, 1),
        "mean_gap_ms": round(mean_gap, 1), "max_gap_ms": round(max_gap, 1), "paused_ms": round(paused, 1),
        "replays": replays, "motor_slips": motor_slips, "corrections": corrections,
        "n_insertions": insertions, "n_deletions": deletions, "n_replacements": replacements,
        "n_reorders": reorders, "distractor_picks": distractor_picks,
        "answer_length_diff": len(answers[0]) - n_ak,
        "attempts": attempts, "correct_first_try": correct_first, "final_correct": final_correct,
        "hesitation_ratio": hes, "pause_ratio": pause_ratio, "first_wrong_answer": first_wrong or "",
        "edit_distance": sum(errors.values()), **errors,
        "n_aksharas": n_ak, "n_marks": n_marks,
    }
    child.first_inputs = (child.first_inputs + [first_input])[-50:]
    child.max_gaps = (child.max_gaps + [max_gap])[-50:]
    child.ability[skill] = min(0.98, a + child.learning)
    return row


def place(child: Child, rows: list[dict], skills: list[str], stage_of: dict) -> None:
    """SinhalaLearner.applyPlacement: the warm-up sets each stage's starting estimate."""
    tested, error_stage = {}, None
    for r in rows:
        tested[r["phonics_skill"]] = 0.6 if r["correct_first_try"] else (0.4 if r["final_correct"] else 0.15)
        if not r["correct_first_try"] and (error_stage is None or r["skill_stage"] < error_stage):
            error_stage = r["skill_stage"]
    max_tested = max(r["skill_stage"] for r in rows)
    for s in skills:
        st = stage_of[s]
        if error_stage is None:
            child.p[s] = tested.get(s, 0.6 if st <= max_tested else 0.3)
            unlocked = st <= max_tested + 1
        elif st < error_stage:
            child.p[s] = tested.get(s, 0.6)
            unlocked = True
        elif st == error_stage:
            child.p[s] = tested.get(s, 0.3)
            unlocked = True
        else:
            child.p[s] = tested.get(s, 0.1)
            unlocked = s in tested
        if unlocked:
            child.unlocked.add(s)


def plan_round(child: Child, wb: pd.DataFrame, skills: list[str], rng) -> list[dict]:
    """Simple adaptive policy (the app's selector adds habit and returning words):
    6 words of the weakest unlocked stage, 2 review, 2 from the next stage."""
    unlocked = [s for s in skills if s in child.unlocked] or skills[:1]
    focus = min(unlocked, key=lambda s: child.p[s] + rng.uniform(0, 0.15))
    nxt = next((s for s in skills if s not in child.unlocked), None)
    picks = []

    def take(skill, n):
        pool = wb[(wb["phonics_skill"] == skill) & (wb["role"] != "placement")]
        if len(pool):
            picks.extend(pool.sample(n=min(n, len(pool)), random_state=int(rng.integers(1 << 31))).to_dict("records"))

    take(focus, 6)
    for s in rng.choice(unlocked, size=2):
        take(str(s), 1)
    if nxt:
        take(nxt, 2)
        if child.p[focus] >= 0.6:
            child.unlocked.add(nxt)
    while len(picks) < 10:
        take(str(rng.choice(unlocked)), 1)
    return picks[:10]


def simulate(n_children: int, rounds: int, seed: int, control: bool):
    rng = np.random.default_rng(seed)
    wb = load_si_word_bank()
    skills = si_skill_order()
    stage_of = dict(zip(wb["phonics_skill"], wb["skill_stage"]))
    for s in skills:
        stage_of.setdefault(s, int(s[1:3]))
    placement = wb[wb["role"] == "placement"].to_dict("records")[:10]

    rows, truth = [], []
    for c in range(n_children):
        child = Child(f"{'ctl' if control else 'sim'}-si-{c:04d}", rng, skills, stage_of)
        for r in range(1, rounds + 1):
            words = placement if r == 1 else plan_round(child, wb, skills, rng)
            round_rows = []
            for i, w in enumerate(words):
                ctx = {"childId": child.id, "sessionId": f"s{(r - 1) // 3 + 1}", "roundNo": r, "wordIndex": i,
                       "timestamp": "", "mode": "placement" if r == 1 else "adaptive"}
                row = play_word(child, w, ctx, control, rng)
                s = w["phonics_skill"]
                before = child.p[s]
                w_ev = si_evidence_weight(row)
                after = before if r == 1 else si_bkt_update(before, w_ev, row["n_aksharas"])
                child.p[s] = after
                row |= {"evidence_weight": w_ev, "p_before": before, "p_after": after}
                round_rows.append(row)
            if r == 1:
                place(child, round_rows, skills, stage_of)
            rows.extend(round_rows)
        for s in skills:
            truth.append({
                "childId": child.id, "phonics_skill": s, "weak": s in child.weak,
                "initial_ability": round(child.initial_ability[s], 3), "final_ability": round(child.ability[s], 3),
                "length_habit": round(child.length_habit, 3), "hal_habit": round(child.hal_habit, 3),
                "lookalike_habit": round(child.lookalike_habit, 3), "speed_ms": round(child.speed_ms, 1),
            })
    df = pd.DataFrame(rows)[SI_FEATURE_COLUMNS]
    for col in ["correct_first_try", "final_correct"]:
        df[col] = df[col].map(lambda v: "true" if v else "false")
    return df, pd.DataFrame(truth)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--children", type=int, default=200)
    ap.add_argument("--rounds", type=int, default=12)
    ap.add_argument("--seed", type=int, default=11)
    args = ap.parse_args()
    for control, name in [(False, "sim_si"), (True, "sim_si_control")]:
        df, truth = simulate(args.children, args.rounds, args.seed + (1000 if control else 0), control)
        write_csv_with_banner(df, DATA / f"{name}_features.csv", SIM_BANNER)
        write_csv_with_banner(truth, DATA / f"{name}_truth.csv", SIM_BANNER)
        errs = {t: int((df[t] > 0).sum()) for t in SI_ERROR_TYPES}
        print(f"{name}: {len(df)} rows, {df['childId'].nunique()} children, first-try right "
              f"{(df['correct_first_try'] == 'true').mean():.0%}; mistake rows {errs}")


if __name__ == "__main__":
    main()
