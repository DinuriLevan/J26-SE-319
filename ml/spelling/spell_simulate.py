"""Generates simulated children in the SAME format as the app's features CSV.

It follows the app's simulator (app/lib/features/spelling/engine/simulator.dart):
weak skills are slower to start, slower between tiles, more often corrected,
and their mistakes land on the target sound (a wrong letter, a left-out
letter — most often in blends — or a doubled letter). b/d/p/q words can be
mirror-flipped. Ability grows a little with every word practised.

Each child also has a personal speed (some children are simply slower),
which is why the app compares hesitation to the child's own running median.

Two data sets are written:
  data/sim_features.csv          behaviour carries a signal (as above)
  data/sim_control_features.csv  "no behaviour signal" control: hesitation,
                                 corrections, replays and pauses are random,
                                 unrelated to how hard the word is
plus the hidden truth for each (data/sim_*truth.csv).

Usage:  python spell_simulate.py [--children 200] [--rounds 12] [--seed 7]
"""
from __future__ import annotations

import argparse
import math
import re

import numpy as np
import pandas as pd

from spell_common import (
    DATA, FEATURE_COLUMNS, SIM_BANNER, bkt_update, evidence_weight, load_word_bank,
    median_or_default, skill_order, write_csv_with_banner,
)

MIRROR = {"b": "d", "d": "b", "p": "q", "q": "p"}
VOWELS = "aeiou"
CONSONANTS = "cfhlmnrstw"
MAX_ATTEMPTS = 3


def grapheme_span(word: str, target: str):
    """Same rule as graphemeSpan() in error_analyzer.dart."""
    if not target.strip():
        return None
    for raw in target.split("|"):
        opt = raw.strip().lower()
        if not opt:
            continue
        if "_" in opt:
            m = re.search(opt.replace("_", "[a-z]"), word)
            if m:
                return m.start(), m.end() - 1
        else:
            i = word.find(opt)
            if i >= 0:
                return i, i + len(opt) - 1
    return None


class Child:
    def __init__(self, cid: str, rng: np.random.Generator, skills: list[str], stage_of: dict):
        self.id = cid
        self.rng = rng
        # Hidden truth: 1–3 weak skills from stages 1–5, the rest fairly secure.
        candidates = [s for s in skills if 1 <= stage_of[s] <= 5]
        n_weak = int(rng.integers(1, 4))
        self.weak = set(rng.choice(candidates, size=n_weak, replace=False).tolist())
        base = float(np.clip(rng.normal(0.86, 0.06), 0.65, 0.97))
        self.ability = {
            s: (float(rng.uniform(0.15, 0.4)) if s in self.weak else float(np.clip(base + rng.normal(0, 0.05), 0.55, 0.98)))
            for s in skills
        }
        self.initial_ability = dict(self.ability)
        self.reversal_rate = 0.0 if rng.random() < 0.6 else float(rng.uniform(0.2, 0.6))
        self.blend_omission = float(rng.uniform(0.3, 0.7))  # share of blend mistakes that drop a letter
        self.speed_ms = float(np.exp(rng.normal(math.log(1800), 0.3)))  # personal first-input speed
        self.gap_ms = float(np.exp(rng.normal(math.log(750), 0.25)))
        self.learning = 0.015
        # Model state, as in the app.
        self.p = {s: 0.1 for s in skills}
        self.p["sight_words"] = 0.3
        self.unlocked = {"sight_words"}
        self.first_inputs: list[float] = []
        self.max_gaps: list[float] = []


def mistake(word: dict, child: Child, weak: bool, reversal: bool, rng) -> list[str]:
    letters = list(word["spelling"])
    if reversal:
        i = next(i for i, c in enumerate(letters) if c in MIRROR)
        letters[i] = MIRROR[letters[i]]
        return letters
    span = grapheme_span(word["spelling"], word["target_grapheme"]) if weak else None
    i = int(rng.integers(len(letters))) if span is None else int(span[0] + rng.integers(span[1] - span[0] + 1))
    blend = word["phonics_skill"].startswith("blend_")
    roll = rng.random()
    if len(letters) > 2 and roll < (child.blend_omission if blend else 0.2):
        del letters[i]
        return letters
    if roll > 0.85:
        letters.insert(i, letters[i])
        return letters
    pool = (VOWELS if letters[i] in VOWELS else CONSONANTS).replace(letters[i], "")
    letters[i] = pool[int(rng.integers(len(pool)))]
    return letters


def classify(target: str, answer: str, tg: str) -> dict:
    """Error counts for the simulated (single-edit) mistakes, using the same
    categories and target-sound rule as analyzeErrors()."""
    out = {t: 0 for t in ["reversal", "vowel_sub", "other_sub", "omission", "insertion", "transposition"]}
    span = grapheme_span(target, tg)
    hit = False
    if len(answer) < len(target):
        i = next((k for k in range(len(answer)) if answer[k] != target[k]), len(answer))
        out["omission"] = 1
        hit = span is not None and span[0] <= i <= span[1]
    elif len(answer) > len(target):
        i = next((k for k in range(len(target)) if answer[k] != target[k]), len(target))
        out["insertion"] = 1
        hit = span is not None and span[0] < i <= span[1] + 1
    else:
        for k, (t, a) in enumerate(zip(target, answer)):
            if t != a:
                if MIRROR.get(t) == a:
                    out["reversal"] += 1
                elif t in VOWELS and a in VOWELS:
                    out["vowel_sub"] += 1
                else:
                    out["other_sub"] += 1
                if span is not None and span[0] <= k <= span[1]:
                    hit = True
    distance = sum(out.values())
    if span is None:
        hit = distance > 0  # no target sound: the whole word is the target
    return out | {"edit_distance": distance, "target_grapheme_error": hit}


def play_word(child: Child, word: dict, ctx: dict, control: bool, rng) -> dict:
    skill = word["phonics_skill"]
    a = child.ability[skill]
    weak = a < 0.5
    target = word["spelling"]
    has_mirror = any(c in MIRROR for c in target)

    answers, correct_at = [], None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        p_ok = min(0.98, a + (attempt - 1) * 0.25)
        reversed_ = has_mirror and rng.random() < child.reversal_rate * (1 if attempt == 1 else 0.5)
        right = (not reversed_) and rng.random() < p_ok
        ans = target if right else "".join(mistake(word, child, weak, reversed_, rng))
        if ans == target:
            right = True
        answers.append(ans)
        if right:
            correct_at = attempt
            break
    attempts = len(answers)
    correct_first = correct_at == 1
    final_correct = correct_at is not None
    first_wrong = next((x for x in answers if x != target), None)
    errors = classify(target, first_wrong, word["target_grapheme"]) if first_wrong else {
        "reversal": 0, "vowel_sub": 0, "other_sub": 0, "omission": 0, "insertion": 0, "transposition": 0,
        "edit_distance": 0, "target_grapheme_error": False,
    }

    # Behaviour. Signal set: weak skills are slower and messier. Control set:
    # the same amounts of noise, but unrelated to the skill.
    slow = (rng.random() < 0.5) if control else weak
    first_input = child.speed_ms * (2.2 if slow else 1.0) * float(np.exp(rng.normal(0, 0.3)))
    mean_gap = child.gap_ms * (1.8 if slow else 1.0) * float(np.exp(rng.normal(0, 0.2)))
    max_gap = mean_gap * float(rng.uniform(1.3, 2.5))
    corrections = int(rng.poisson(0.55 if control else (1.0 if weak else 0.15)))
    motor_slips = int(rng.poisson(0.1))
    replays = int(rng.poisson(0.45 if control else (0.8 if weak else 0.2)))
    paused = float(rng.choice([0.0, 0.0, 0.0, 0.0, rng.uniform(2000, 60000)])) if rng.random() < 0.05 else 0.0

    # Edits on the answer line.
    reorders = int(rng.binomial(corrections, 0.3))
    replacements = int(rng.binomial(corrections - reorders, 0.5))
    deletions = corrections - reorders - replacements
    retyped = sum(errors["edit_distance"] if i else 0 for i, _ in enumerate(answers))  # letters re-placed after bounce-back
    insertions = len(answers[0]) + deletions + retyped
    word_letters = set(target)
    distractor_picks = sum(1 for c in "".join(answers) if c not in word_letters) + int(rng.binomial(replacements, 0.3))

    total = first_input + len(target) * mean_gap * attempts + corrections * 900 + (attempts - 1) * 2500
    hes = first_input / median_or_default(child.first_inputs)
    pause_ratio = max_gap / median_or_default(child.max_gaps)

    row = {
        **ctx,
        "word_id": word["word_id"], "word": word["word"], "phonics_skill": skill,
        "skill_stage": int(word["skill_stage"]), "difficulty": int(word["difficulty"]),
        "first_input_ms": round(first_input, 1), "total_ms": round(total, 1),
        "mean_gap_ms": round(mean_gap, 1), "max_gap_ms": round(max_gap, 1), "paused_ms": round(paused, 1),
        "replays": replays, "motor_slips": motor_slips, "corrections": corrections,
        "n_insertions": insertions, "n_deletions": deletions, "n_replacements": replacements,
        "n_reorders": reorders, "distractor_picks": distractor_picks,
        "answer_length_diff": len(answers[0]) - len(target),
        "attempts": attempts, "correct_first_try": correct_first, "final_correct": final_correct,
        "hesitation_ratio": hes, "pause_ratio": pause_ratio, "first_wrong_answer": first_wrong or "",
        **{k: errors[k] for k in ["edit_distance", "reversal", "vowel_sub", "other_sub", "omission", "insertion", "transposition"]},
        "target_grapheme_error": bool(errors["target_grapheme_error"]),
    }
    # Medians are updated after the features, as in the app.
    child.first_inputs = (child.first_inputs + [first_input])[-50:]
    child.max_gaps = (child.max_gaps + [max_gap])[-50:]
    # Learning.
    child.ability[skill] = min(0.98, a + child.learning)
    return row


def place(child: Child, rows: list[dict], skills: list[str], stage_of: dict) -> None:
    """LearnerModel.applyPlacement, simplified to what the simulation needs."""
    tested, error_stage = {}, None
    for r in rows:
        tested[r["phonics_skill"]] = 0.6 if r["correct_first_try"] else (0.4 if r["final_correct"] else 0.15)
        if not r["correct_first_try"] and (error_stage is None or r["skill_stage"] < error_stage):
            error_stage = r["skill_stage"]
    max_tested = max(r["skill_stage"] for r in rows)
    for s in skills:
        st = stage_of[s]
        if s == "sight_words":
            child.p[s] = 0.3
        elif error_stage is None:
            child.p[s] = tested.get(s, 0.6 if st <= max_tested else 0.3)
        elif st < error_stage:
            child.p[s] = tested.get(s, 0.6)
        elif st == error_stage:
            child.p[s] = tested.get(s, 0.3)
        else:
            child.p[s] = tested.get(s, 0.1)
        if s == "sight_words" or error_stage is None or st <= error_stage:
            child.unlocked.add(s)


def plan_round(child: Child, wb: pd.DataFrame, skills: list[str], rng) -> list[dict]:
    """A simple adaptive policy (the app's selector is richer; the classifier
    only needs realistic practice histories): 6 words of the weakest unlocked
    skill, 2 review, 2 from the next locked skill."""
    unlocked = [s for s in skills if s in child.unlocked]
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
    wb = load_word_bank()
    skills = skill_order(wb)
    stage_of = dict(zip(wb["phonics_skill"], wb["skill_stage"]))
    placement = wb[wb["role"] == "placement"].sort_values("skill_stage").head(10).to_dict("records")

    rows, truth = [], []
    for c in range(n_children):
        child = Child(f"{'ctl' if control else 'sim'}-{c:04d}", rng, skills, stage_of)
        for r in range(1, rounds + 1):
            words = placement if r == 1 else plan_round(child, wb, skills, rng)
            round_rows = []
            for i, w in enumerate(words):
                ctx = {
                    "childId": child.id, "sessionId": f"s{(r - 1) // 3 + 1}", "roundNo": r, "wordIndex": i,
                    "timestamp": "", "mode": "placement" if r == 1 else "adaptive", "use_behaviour": True,
                }
                row = play_word(child, w, ctx, control, rng)
                s = w["phonics_skill"]
                before = child.p[s]
                w_ev = evidence_weight(row)
                after = before if r == 1 else bkt_update(before, w_ev, len(w["spelling"]))
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
                "reversal_rate": round(child.reversal_rate, 3), "speed_ms": round(child.speed_ms, 1),
            })
    df = pd.DataFrame(rows)[FEATURE_COLUMNS]
    for c in ["use_behaviour", "correct_first_try", "final_correct", "target_grapheme_error"]:
        df[c] = df[c].map(lambda v: "true" if v else "false")  # as the app writes booleans
    return df, pd.DataFrame(truth)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--children", type=int, default=200)
    ap.add_argument("--rounds", type=int, default=12)
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()
    for control, name in [(False, "sim"), (True, "sim_control")]:
        df, truth = simulate(args.children, args.rounds, args.seed + (1000 if control else 0), control)
        write_csv_with_banner(df, DATA / f"{name}_features.csv", SIM_BANNER)
        write_csv_with_banner(truth, DATA / f"{name}_truth.csv", SIM_BANNER)
        print(f"{name}: {len(df)} rows, {df['childId'].nunique()} children, "
              f"omission rows {int((df['omission'] > 0).sum())}, insertion rows {int((df['insertion'] > 0).sum())}")


if __name__ == "__main__":
    main()
