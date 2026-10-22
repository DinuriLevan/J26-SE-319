# Math & Memory — next-attempt models

Two small supervised models that pick where a child's **next** attempt starts, from how they did in the attempt they just finished. They run on the phone, offline.

| Model | Predicts | Algorithm (chosen on validation) | Artifact |
|---|---|---|---|
| `number_quest_next_level` | per skill: level change −1 / 0 / +1 | Decision tree, depth 6 | `app/assets/models/math_memory/number_quest_next_level.json` (6 KB) |
| `memory_match_next_config` | rung change on a difficulty ladder (−3…+3) | Random forest, 30 trees, depth 8 | `app/assets/models/math_memory/memory_match_next_config.json` (544 KB) |

> ⚠️ **Trained on synthetic data only.** There is no real learner data yet. The models are a working, evaluated *prototype* of the pipeline, not a model validated with children. Re-train on real, anonymised attempts before drawing any conclusions about learning benefit.

## Reproduce

No local Python needed — from the repo root:

```sh
docker run --rm -v "$PWD":/repo -w /repo/ml/math_memory python:3.12-slim \
  sh -c "pip install -q -r requirements.txt && python train.py"
```

(Git Bash on Windows: prefix with `MSYS_NO_PATHCONV=1` and use `"$(pwd -W)"`.)

Seeds and package versions are fixed; re-running produces identical models (only `trained_at` changes). Outputs:

- `app/assets/models/math_memory/*.json` — bundled model artifacts (with version, features, metrics, dataset info)
- `reports/evaluation.md`, `reports/evaluation.json` — test metrics vs. baselines
- `app/test/features/math_memory/fixtures/*_parity.json` — cases the Flutter tests use to prove the app's evaluator matches scikit-learn exactly

## Files

| File | Purpose |
|---|---|
| `features.py` | Feature definitions. **Must match** `app/lib/features/math_memory/ml/next_attempt_features.dart`; the app refuses a model whose `feature_names` differ and falls back to its rules engine. |
| `simulate.py` | Synthetic learner simulator and the expert labelling policy. |
| `train.py` | Data generation, split, model selection, evaluation, export. |

## Dataset (synthetic, expert-authored)

Each simulated child has hidden abilities:

- **Number Quest**: a comfortable level per skill (general ability + typical skill difficulty + individual variation), answer speed, and how sharply success drops above their level.
- **Memory Match**: picture capacity at 6 s of looking, how much extra looking time helps, speed, and steepness.

We simulate the attempts the app would run (baseline plan, then scored attempts at random starting difficulties with small in-attempt changes, two tries per activity), and compute **exactly the features the app computes**. 4,000 children × 4 attempts × 5 skills (80,000 Number Quest rows); 8,000 children × 4 attempts (32,000 Memory Match rows). Train/validation/test are split **by child** (70/15/15), so no child appears in both training and test.

**Label (expert policy)** — what we'd choose if we could see the hidden ability: the hardest setting where the child would get about **70% right first time**, limited to a small step from the current one (Number Quest: ±1 level; Memory Match: ±2 rungs, ±3 after the baseline). The model has to infer this from one noisy attempt.

**Limitations**: the simulator's assumptions (logistic success curves, the 70% target, skill difficulty offsets) are design choices, not measurements. Real children may differ (fatigue, guessing, language, motivation). Accuracy here measures agreement with the expert policy on simulated children only.

## Features

Number Quest (one row per skill asked in the attempt): `is_baseline`, `ref_level` (baseline: highest level asked; scored: the skill's starting level), `mean_level`, `n_questions`, `first_try_acc`, `eventual_acc`, `hint_rate`, `mean_rt_s` (capped 60 s), `max_miss_streak`.

Memory Match (one row per attempt): `is_baseline`, `ref_rung` (baseline: rung 3 = 4 pictures/6 s; scored: rung nearest the first round), `mean_positions`, `mean_seconds`, `first_try_acc`, `eventual_acc`, `wrong_per_round`, `mean_rt_s`, `max_miss_streak`, `largest_board_first_try_acc`.

Memory Match ladder (pictures, seconds): (3,8) (3,7) (3,6) (4,6) (4,5) (5,5) (5,4) (6,4) (7,4) (8,4) (9,4) — neighbours differ in one factor only.

## Results (held-out simulated children)

From `reports/evaluation.md` (v1.0.0):

| | Number Quest accuracy | Memory Match accuracy |
|---|---|---|
| **Trained model** | **0.795** (MAE 0.22 levels) | **0.725** (MAE 0.39 rungs) |
| Rules baseline (threshold rules like the app's `rules_v1`) | 0.671 | 0.145 |
| Keep the same difficulty | 0.197 | 0.078 |

The model is too hard for the child (above the expert target) on 13% of Number Quest and 13% of Memory Match test cases, vs. 29% / 42% for the rules baseline. The Memory Match rules baseline only ever moves ±1 rung, which is part of why it scores low against a target that can move further after a baseline.

## Using real data later

Every completed attempt the app queues (`component_name: math_memory`) includes the features (`next_attempt.features` / `next_attempt.skills.*.features`), the model's prediction, and the activity-level results of the following attempt — enough to build a real dataset (e.g. label = the setting where the child's *next* attempt landed near 70% first-try). Replace `simulate.py`'s generator with a loader for those rows, keep the same feature definitions, re-run `train.py`, and bump `MODEL_VERSION`.
