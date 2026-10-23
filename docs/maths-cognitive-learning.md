# Maths & Cognitive Learning Section

AkuRin's maths and cognitive learning component. It has two adaptive games for children aged 7–9 with dyslexia:

- **Number Quest** builds number skills through visual quantities and arithmetic.
- **Memory Match** builds concentration and visual memory through picture-position recall.

In the app this section is the **Math** tab, titled *Math & Memory*. It works fully offline on low-cost Android phones. After each completed attempt, a **trained machine-learning model** running on the phone chooses the difficulty of the child's next attempt.

> **Important:** the models are trained on **synthetic (simulated) learner data**, because no real learner data exists yet. They are a working, evaluated prototype of the ML pipeline, **not** a model validated with real children. See [Limitations](#9-limitations).

---

## Contents

1. [What the child sees](#1-what-the-child-sees)
2. [How an attempt works](#2-how-an-attempt-works)
3. [The two games](#3-the-two-games)
4. [How adaptation works](#4-how-adaptation-works)
5. [How the ML models were trained](#5-how-the-ml-models-were-trained)
6. [Evaluation results](#6-evaluation-results)
7. [Running the models on the phone](#7-running-the-models-on-the-phone)
8. [Data saved and synced](#8-data-saved-and-synced)
9. [Limitations](#9-limitations)
10. [Where the code lives](#10-where-the-code-lives)
11. [Testing](#11-testing)
12. [Retraining the models](#12-retraining-the-models)

---

## 1. What the child sees

| Screen | Purpose |
|---|---|
| **Game menu** ("Let's Play & Learn!") | Two large cards: Number Quest (orange, *Maths Adventure*) and Memory Match (purple, *Brain & Memory*), each with a **Play Now** button. |
| **Game intro** | A picture, a short explanation, 3 simple steps, **Start Game**, and **How to play**. |
| **Tutorial** (first visit only, can be reopened later) | 3 steps with "1 of 3", **Back** / **Next** / **Let's Play!**, ending with a practice question that never counts. |
| **Game** | One activity at a time, with large answer buttons and friendly feedback. |
| **Baseline complete** | "Great exploring! Let's find the activities that suit you." No score is shown. |
| **Results** (scored attempts) | 0–3 stars, correct answers, percentage, points, **Play Again** and **Back to Games**. |

### Designed for children with dyslexia
- Short, single-line instructions, supported by pictures.
- Lexend font with Sinhala fallback. Large text and buttons (at least 48 dp).
- Every picture is drawn in code, so nothing is downloaded and everything works offline.
- No flashing and no countdown numbers. The child presses **Next** when ready.
- Feedback is always kind. A wrong answer gets a hint ("Good try! Try again."), never a "failed" message.
- Colour is never the only signal; ticks and crosses are shown too.

---

## 2. How an attempt works

Each game keeps **its own** attempt history. Playing Number Quest never affects Memory Match.

```
First visit ──► Tutorial (practice, not recorded)
                   │
                   ▼
Attempt 1 ──► BASELINE (ungraded)
                   │  model predicts the starting difficulty
                   ▼
Attempt 2+ ─► SCORED + ADAPTIVE ──► results with stars
                   │  model predicts the next starting difficulty
                   └──────────── repeats after every completed attempt
```

| Rule | Behaviour |
|---|---|
| Tutorial practice | Never counted or saved. |
| First completed attempt | **Baseline assessment.** A fixed set of activities. Results are collected, but no points, percentage or stars are shown. The child is never told they are being tested. |
| Second attempt onwards | **Scored and adaptive.** Points, percentage and 0–3 stars. |
| Leaving mid-attempt | The child confirms "Stop playing?". The attempt is **not counted**: the attempt number and difficulty don't change, so an unfinished baseline never counts as done. The partial data is saved and marked `abandoned`. |
| Earlier results | Never changed later. A baseline stays ungraded for good. |

### Answering
Each activity allows **two tries**:
1. Right first time: "Great job!" and full points.
2. Wrong first time: a short hint, then a second try.
3. Wrong again: the answer is gently shown ("The answer is 8. Let's keep going!").

### Scoring (scored attempts only)

| | Value |
|---|---|
| Right first try | 10 points |
| Right after a hint | 5 points |
| Percentage | points ÷ maximum points |
| Stars | ★ at 40% or more, ★★ at 70% or more, ★★★ at 90% or more |

Every star count, including zero, gets an encouraging message.

---

## 3. The two games

### Number Quest — maths through visual quantities

Covers 5 skills: **counting, addition, subtraction, multiplication and division**.

- Quantities are shown as pictures (apples, oranges, stars, fish, flowers, balloons): two groups to add, crossed-out objects to subtract, equal groups to multiply, and plates to share onto for division.
- Harder questions switch from pictures to large number blocks, moving from concrete to abstract.
- Each question has 3 large multiple-choice answers; no typing.
- Each skill has its own difficulty **level from 1 to 5**:

| Level | Counting | Addition (total) | Subtraction (start) | Multiplication | Division |
|---|---|---|---|---|---|
| 1 | 1–5 | up to 5 | up to 5 | 2 × 1–3 | ÷2, answer 1–3 |
| 2 | 4–10 | up to 10 | up to 10 | 2–3 × 1–5 | ÷2–3, answer 1–5 |
| 3 | 8–15 | up to 15 | up to 15 | 2–5 × 2–5 | ÷2–5, answer 2–5 |
| 4 | 12–20 | up to 20 | up to 20 | 2–5 × 2–10 | ÷2–5, answer 2–10 |
| 5 | 15–20 | up to 50 | up to 50 | 2–10 × 2–10 | ÷2–10, answer 2–10 |

- **Baseline:** 10 fixed questions, with each skill asked at level 1 and then level 2.
- **Scored attempts:** 10 questions chosen adaptively.

### Memory Match — concentration and visual memory

Each round follows the same sequence:
1. Pictures appear face-up on a 3×3 board.
2. Instruction: **"Look carefully and remember where each picture is!"** A calm bar shows the looking time (no numbers), and an **I'm ready!** button lets the child finish early.
3. The pictures turn face-down and show **card numbers**.
4. One target picture is shown: "Where was the fish?"
5. The child taps the numbered card where it was.
6. Kind feedback, then **Next**.

- All pictures on a board are different, so each target has exactly one correct card.
- Repeated taps, taps on empty cells, and taps after the round is decided are ignored. A round can never be scored twice.
- Difficulty is the **number of pictures** (3–9) and the **looking time** (3–10 seconds).
- **Baseline:** 6 fixed rounds: 3, 3, 4, 4, 5 and 5 pictures, 6 seconds each.
- **Scored attempts:** 6 adaptive rounds.

---

## 4. How adaptation works

Adaptation works on two levels:

| Level | Done by | What it decides |
|---|---|---|
| **Between attempts** | **Trained ML model**, on the phone | Where the **next attempt starts**: each Number Quest skill's level, or the Memory Match board size and looking time. |
| **Within an attempt** | Fixed rules (`rules_v1`) | Small, gradual adjustments while the child plays, such as extra practice after repeated mistakes. |

### Between attempts: the ML model
After **every completed attempt, including the baseline**:
1. Performance features are calculated from the attempt (see [§5.3](#53-input-features)).
2. The model predicts the next starting difficulty.
3. The prediction is checked against safe limits and saved.
4. The next attempt's question or board generator uses it.

| Game | Model output | Safe limits |
|---|---|---|
| Number Quest | Per skill: **one level easier, same, or one level harder** | Level 1–5, at most 1 level of change. Skills not asked keep their level. |
| Memory Match | A move on an **11-step difficulty ladder** | At most 2 steps (3 after the baseline). Each step changes only one factor. |

The Memory Match difficulty ladder (pictures, seconds of looking time), from easiest to hardest:

```
(3, 8s) → (3, 7s) → (3, 6s) → (4, 6s) → (4, 5s) → (5, 5s) → (5, 4s) → (6, 4s) → (7, 4s) → (8, 4s) → (9, 4s)
```

### Within an attempt: rules
- **Number Quest:**
  - 3 quick first-try answers in a row raise that skill one level. Answers slower than 20 seconds don't count towards this.
  - 2 misses in a row add **2 extra practice questions in that skill, with pictures**, and lower that skill one level. Other skills are unaffected.
  - After any change, the level can't change again for 2 answers, so it doesn't swing up and down.
- **Memory Match:**
  - 2 right in a row make it harder by one step, alternating between adding a picture and taking a second off.
  - 2 misses in a row make it easier, first by adding a second, then by removing a picture.
  - Only one factor changes at a time, with a 2-round pause between changes.

### Fallback
If the model can't be used (file missing or broken, feature mismatch, any error), the game keeps working and the earlier rules choose the next difficulty. Every result records whether the **model** or the **fallback** made the choice.

---

## 5. How the ML models were trained

All training code is in [`ml/math_memory/`](../ml/math_memory/).

### 5.1 The problem
The task is a **supervised classification** problem:

> *Given how a child performed in one attempt, what difficulty should their next attempt start at?*

| Model | Predicts | Classes |
|---|---|---|
| `number_quest_next_level` | Level change for one skill | −1, 0, +1 |
| `memory_match_next_config` | Move on the difficulty ladder | −3 … +3 |

Predicting a **change** from the current difficulty (instead of an absolute value) keeps every output small, safe and within limits.

### 5.2 Training data: synthetic learners
There is **no real learner data yet**, so the training data comes from an expert-authored **learner simulator** ([`simulate.py`](../ml/math_memory/simulate.py)).

**Simulated children.** Each one has hidden abilities:

| Game | Hidden traits per simulated child |
|---|---|
| Number Quest | A comfortable level per skill (general ability + typical skill difficulty + personal variation), answer speed, and how sharply success drops above their level. |
| Memory Match | How many pictures they can remember with 6 s of looking, how much extra looking time helps, answer speed, and how sharply success drops. |

The general skill difficulty order is: counting is easiest, then addition, subtraction, multiplication, and division is hardest.

**Simulated play.** Each child plays the same attempts the app runs:
- The baseline plan first, then scored attempts at different starting difficulties, with small changes during the attempt.
- Two tries per activity: the chance of success falls as the difficulty passes the child's ability, and knowledge still helps on the second try.
- Realistic, varied response times.

**Features.** From each simulated attempt we compute **exactly the same features the app computes** on the phone.

**Labels (expert policy).** Each attempt is labelled with the difficulty an expert would choose *if they could see the child's hidden ability*:

> **The hardest difficulty at which the child would get about 70% right on the first try**, the zone where practice is challenging but achievable, limited to a small step from the current difficulty:
> - Number Quest: ±1 level.
> - Memory Match: ±2 steps, or ±3 after the baseline.

The model never sees the hidden ability. It has to **infer** the right next difficulty from one noisy attempt, which is exactly what it does in the app.

| Dataset | Simulated children | Attempts each | Rows |
|---|---|---|---|
| Number Quest | 4,000 | 4 (× 5 skills) | 80,000 |
| Memory Match | 8,000 | 4 | 32,000 |

### 5.3 Input features

**Number Quest** (one row per skill asked in the attempt):

| Feature | Meaning |
|---|---|
| `is_baseline` | 1 if this was the baseline attempt |
| `ref_level` | Level the change is measured from (baseline: highest level asked; scored: the skill's starting level) |
| `mean_level` | Average level of the skill's questions |
| `n_questions` | Questions asked for the skill |
| `first_try_acc` | Share answered right first time |
| `eventual_acc` | Share answered right on either try |
| `hint_rate` | Share that needed a hint |
| `mean_rt_s` | Average time to first answer, in seconds (capped at 60) |
| `max_miss_streak` | Longest run of mistakes in a row |

**Memory Match** (one row per attempt):

| Feature | Meaning |
|---|---|
| `is_baseline` | 1 if this was the baseline attempt |
| `ref_rung` | Ladder step the change is measured from |
| `mean_positions` | Average number of pictures |
| `mean_seconds` | Average looking time |
| `first_try_acc` | Share recalled right first time |
| `eventual_acc` | Share recalled right on either try |
| `wrong_per_round` | Wrong cards tapped per round |
| `mean_rt_s` | Average time to first tap, in seconds |
| `max_miss_streak` | Longest run of misses |
| `largest_board_first_try_acc` | First-try accuracy on the biggest boards in the attempt |

The features are defined in both [`features.py`](../ml/math_memory/features.py) (training) and `next_attempt_features.dart` (app), and **must be kept the same**. The app checks the model's feature list and uses the fallback if it doesn't match.

### 5.4 Training procedure
1. **Split by child:** 70% training, 15% validation, 15% test. No simulated child appears in more than one split, which avoids leakage.
2. **Candidate models** (scikit-learn, with balanced class weights and at least 25 samples per leaf):
   - Decision trees with depth 4, 6 and 8.
   - Random forests of 30 trees with depth 6 and 8.
3. **Model selection:** the highest validation accuracy, preferring the simpler model when the difference is within 0.005.
4. **Final fit** on training + validation data, then **one evaluation** on the untouched test set.
5. **Baseline comparison** against two simple strategies:
   - **Keep the same:** never change difficulty.
   - **Rules:** accuracy-threshold rules similar to the app's original rules engine.
6. **Export** to compact JSON, with a check that the exported model gives **100% identical** predictions to scikit-learn.

| Validation accuracy | Decision tree d4 | DT d6 | DT d8 | Random forest d6 | RF d8 |
|---|---|---|---|---|---|
| Number Quest | 0.764 | **0.792** ✔ | 0.787 | 0.791 | 0.794 |
| Memory Match | 0.719 | 0.729 | 0.727 | 0.734 | **0.739** ✔ |

**Chosen models:**
- Number Quest: **decision tree, depth 6** (6 KB). It is simpler and within 0.005 of the best.
- Memory Match: **random forest, 30 trees, depth 8** (544 KB).

**Reproducibility:** fixed random seed (`20261018`), pinned package versions (numpy 2.1.3, scikit-learn 1.5.2), and a Docker-based run. Retraining from scratch produces identical models; only the timestamp differs.

---

## 6. Evaluation results

Measured on the **held-out test set of simulated children** (model version 1.0.0). Full report: [`ml/math_memory/reports/evaluation.md`](../ml/math_memory/reports/evaluation.md).

### Number Quest — next level per skill

| | Accuracy | Macro-F1 | Mean error (levels) | Within 1 level | Too hard | Too easy |
|---|---|---|---|---|---|---|
| **Trained model** | **0.795** | **0.753** | **0.223** | 0.982 | **0.130** | 0.074 |
| Rules baseline | 0.671 | 0.591 | 0.387 | 0.942 | 0.294 | 0.034 |
| Keep the same | 0.197 | 0.110 | 0.803 | 1.000 | 0.460 | 0.343 |

Model accuracy is 0.737 after a baseline attempt and 0.814 after a scored attempt.

### Memory Match — next board configuration

| | Accuracy | Macro-F1 | Mean error (steps) | Within 1 step | Too hard | Too easy |
|---|---|---|---|---|---|---|
| **Trained model** | **0.725** | **0.629** | **0.391** | **0.899** | **0.131** | 0.144 |
| Rules baseline | 0.145 | 0.100 | 1.055 | 0.806 | 0.418 | 0.437 |
| Keep the same | 0.078 | 0.021 | 1.801 | 0.271 | 0.433 | 0.489 |

Model accuracy is 0.668 after a baseline attempt and 0.744 after a scored attempt.

### What this shows
- Both models clearly beat both baselines at recovering the expert target from a single attempt.
- The models set the difficulty **too hard much less often** than the rules: 13% against 29% (Number Quest) and 42% (Memory Match). This matters for keeping children motivated.
- The Memory Match rules baseline can only move one step at a time, which partly explains its low score.
- Predictions after a baseline are less accurate than after a scored attempt, because the baseline gives only 2 questions per skill.

> These numbers measure agreement with the expert policy **on simulated children**. They are **not** evidence of learning benefit for real children.

---

## 7. Running the models on the phone

| Requirement | How it is met |
|---|---|
| **Offline** | Model files are bundled with the app (`app/assets/models/math_memory/`). No network or backend request is needed. |
| **No extra libraries** | A small Dart tree evaluator (`TreeEnsembleModel`) runs the exported trees. No TensorFlow Lite or ONNX runtime. |
| **Exact match with training** | The evaluator compares values the way scikit-learn does (float32) and averages trees the same way. 600 test cases confirm identical results. |
| **Safe output** | Every prediction is limited to the allowed range before use. |
| **Never blocks play** | Any failure falls back to the rules, and the game continues. |

---

## 8. Data saved and synced

- **On the phone:** each game's progress is saved in the local Drift database, table `local_learner_progress`, one row per child per game. This keeps attempt counts, current difficulty and history across app restarts.
- **Synced:** every finished or abandoned attempt is added to the existing offline queue (`pending_activity_results`) and sent to the backend's `POST /activity-results` when the phone is online.

| Field | Value |
|---|---|
| `component_name` | `math_memory` |
| `activity_id` | `number_quest` or `memory_match` |

The `result_payload` (schema version 1) contains:
- the attempt ID and number, the attempt type (`baseline` or `scored`), and the completion status
- activity-level results: question or board, correct, tries, hint shown, response time
- per-skill or recall summaries
- the score (empty for baselines)
- a **`next_attempt`** block:
  - the source (`model` or `fallback`), the model name and version
  - the features used and the model's confidence in each option
  - the chosen next difficulty and the rules' alternative
  - the reason, if the fallback was used

No names or other personal details are stored.

---

## 9. Limitations

1. **Synthetic training data.** The simulator's assumptions (success curves, the 70% target, skill difficulty order) are design choices, not measurements of real children. Real children may differ because of fatigue, guessing, language or motivation.
2. **Not clinically validated.** The baseline estimates a starting difficulty; it is **not** a diagnostic assessment.
3. **Feature definitions exist twice** (Python and Dart) and must be kept in sync by hand. A mismatch safely triggers the fallback.
4. **Progress is not yet sent to the backend's learner-progress endpoint.** It is kept on the phone, and can be rebuilt from the synced results.
5. **Thresholds are untuned:** the scoring thresholds and in-attempt rules are sensible defaults that haven't been tested with children.

---

## 10. Where the code lives

| Path | Contents |
|---|---|
| `app/lib/features/math_memory/math_game_selection_screen.dart` | Game menu |
| `app/lib/features/math_memory/number_quest/` | Number Quest: intro, tutorial, game screen, question generator, rules, session |
| `app/lib/features/math_memory/memory_match/` | Memory Match: intro, tutorial, game screen, board generator, rules, session |
| `app/lib/features/math_memory/ml/` | Feature extraction, tree evaluator, next-attempt planner |
| `app/lib/features/math_memory/engine/` | Shared attempt types and scoring |
| `app/lib/features/math_memory/data/` | Progress saving and result queueing |
| `app/lib/features/math_memory/widgets/` | Shared art, feedback, tutorial and result screens |
| `app/assets/models/math_memory/` | Bundled model files |
| `ml/math_memory/` | Training pipeline, simulator, evaluation reports |
| `docs/math-memory-adaptive-engine.md` | Detailed adaptation rules |

---

## 11. Testing

Run from `app/`:

```sh
flutter analyze
flutter test test/features/math_memory
```

The tests cover:
- the menu, intro screens, tutorial and navigation
- baseline vs. scored attempts, and independent history per game
- tutorial practice not counting, and unfinished attempts not counting
- no score, percentage or stars on the baseline
- scoring and star thresholds
- per-skill tracking, extra practice after mistakes, and gradual difficulty increases
- Memory Match hiding the pictures and checking the original position
- repeated taps never scoring twice
- results saved locally and queued for sync
- **ML:**
  - exact Python/Dart match on 600 cases
  - loading the models from the bundled files with no network
  - predictions staying within limits
  - stronger performance leading to a harder next attempt
  - the next attempt using the predicted difficulty
  - the fallback working when the model fails

---

## 12. Retraining the models

From the repository root (no local Python needed):

```sh
docker run --rm -v "$PWD":/repo -w /repo/ml/math_memory python:3.12-slim \
  sh -c "pip install -q -r requirements.txt && python train.py"
```

On Windows Git Bash, add `MSYS_NO_PATHCONV=1` before the command and use `"$(pwd -W)"` instead of `"$PWD"`.

This regenerates:
- the model files in the app
- the evaluation report
- the test fixtures

Then run the Flutter tests.

**Moving to real data:** the synced results already contain everything needed: the features, the model's prediction, and how the child did on the following attempt. Replace the simulator with a loader for those (anonymised) records, keep the same feature definitions, retrain, and increase `MODEL_VERSION`.
