# Maths & Cognitive Learning — ML Model

A full, technical account of the two on-device machine-learning models that drive adaptive difficulty in AkuRin's **Math & Memory** section (the *Math* tab in the app). This document is a companion to [maths-cognitive-learning.md](maths-cognitive-learning.md), which focuses on the user experience; here we focus on the model itself: what problem it solves, how it was developed, how it was trained, how it runs on the phone, and where it falls short.

> **Status:** both models are a **working, evaluated prototype**. They are trained on **synthetic learner data** produced by an expert-authored simulator, because no real learner data exists yet. The pipeline is production-ready; the model's benefit for real children is still unproven. See [§13 Limitations](#13-limitations).

---

## Contents

1. [What the models do](#1-what-the-models-do)
2. [Why ML and not just rules](#2-why-ml-and-not-just-rules)
3. [Problem framing](#3-problem-framing)
4. [Development timeline](#4-development-timeline)
5. [Training data: the learner simulator](#5-training-data-the-learner-simulator)
6. [Features](#6-features)
7. [Labels: the expert policy](#7-labels-the-expert-policy)
8. [Model candidates and training procedure](#8-model-candidates-and-training-procedure)
9. [Evaluation](#9-evaluation)
10. [Export format and on-device inference](#10-export-format-and-on-device-inference)
11. [Integration with the app](#11-integration-with-the-app)
12. [Reproducibility](#12-reproducibility)
13. [Limitations](#13-limitations)
14. [Path to real-learner data](#14-path-to-real-learner-data)
15. [Where the code lives](#15-where-the-code-lives)
16. [Glossary](#16-glossary)

---

## 1. What the models do

The Math & Memory section has two adaptive games for children aged 7–9 with dyslexia:

- **Number Quest** — counting, addition, subtraction, multiplication, and division, each on an independent 1–5 difficulty level.
- **Memory Match** — picture-position recall on an 11-step difficulty ladder of `(pictures, looking-time-seconds)`.

After every completed attempt (the ungraded baseline attempt and every scored attempt that follows), a trained ML model running **on the phone** reads a small feature vector summarising the child's performance in that attempt and predicts **where the next attempt should start**.

| Model | Predicts | Classes | Chosen algorithm | Artifact size |
|---|---|---|---|---|
| `number_quest_next_level` | Change in level for one skill | −1 / 0 / +1 | Decision tree, depth 6 | ~6 KB |
| `memory_match_next_config` | Change in ladder rung for the whole game | −3 … +3 | Random forest, 30 trees, depth 8 | ~544 KB |

Both models predict a **delta** (a change) from a reference difficulty, not an absolute value. This keeps outputs small and safe: every prediction is bounded by the number of classes and clamped by the app before use, so the game can never jump from the easiest to the hardest setting in one step.

---

## 2. Why ML and not just rules

The app also contains a hand-written **rules engine** (`rules_v1`) that fires during an attempt (e.g. "three fast correct answers in a row → one level up"). It handles within-attempt tuning, where the signal is immediate and local.

The **between-attempt** decision — "what level should the whole next attempt begin at?" — is a harder, more global inference, for several reasons:

- A single attempt is short and noisy (10 Number Quest questions, 6 Memory Match rounds). First-try accuracy can swing wildly between attempts of equal difficulty.
- Signals interact. In Number Quest, response time matters only when accuracy is high; in Memory Match, accuracy on the biggest board of the attempt is more informative than overall accuracy.
- Simple accuracy thresholds either overshoot (too hard, child demotivated) or undershoot (too easy, child bored). Our rules baseline — the strongest hand-written policy we could write — is too hard on **29%** of Number Quest cases and **42%** of Memory Match cases, versus **13%** / **13%** for the trained model.

Rules remain the fallback: if the model file is missing, feature names don't match, or inference raises, the game keeps running with `rules_v1`. Nothing about the ML path is user-visible when it fails.

---

## 3. Problem framing

Both models are framed as **supervised classification over a bounded step size**:

> *Given a feature vector summarising one completed attempt, predict the integer change in difficulty for the next attempt.*

**Why delta classification and not regression over absolute difficulty?**
1. **Bounded output.** The number of classes = the number of allowed steps. The app can never ask for an unreachable difficulty.
2. **Pedagogically meaningful.** "Up one" and "stay" are the actions a tutor would take; a regression target of 2.73 is not.
3. **Easier to label.** The expert policy is naturally expressed as "move toward the ideal, but no more than *k* steps per attempt."
4. **Explainable.** A decision tree splitting on `first_try_acc` and `hint_rate` is easy to inspect and justify to a reviewer.

**Why one row per Number Quest *skill* instead of one row per attempt?** Each of the five skills has its own level and its own questions in an attempt. Predicting per skill means a child who's strong at counting but weak at division gets each skill tuned independently, with roughly the same amount of per-skill signal (2 baseline questions, 1–3 scored).

**Why one row per Memory Match attempt (not per round)?** Memory Match is a single game with one global board size; rounds within an attempt share the same `(pictures, seconds)` on the baseline and drift by at most one factor during scored play. The attempt-level summary carries all the signal; a per-round model would just re-aggregate it less cleanly.

---

## 4. Development timeline

The pipeline was built in roughly this order; the stages correspond directly to the files in [`ml/math_memory/`](../ml/math_memory/):

1. **Game design finalised** — scoring, baseline plan, ladder, in-attempt rules. These fix the inputs the model will ever see and the outputs it is allowed to make.
2. **Feature vector agreed** — the exact numeric summary the app would compute after an attempt. Defined once, in Python ([`features.py`](../ml/math_memory/features.py)) and Dart (`app/lib/features/math_memory/ml/next_attempt_features.dart`).
3. **Simulator written** — ([`simulate.py`](../ml/math_memory/simulate.py)) generates synthetic children with hidden abilities and plays them through the exact attempt structure the app uses. The simulator shares the feature code with training, so there is no train/serve skew *inside* the Python stack.
4. **Expert labelling policy chosen** — "the hardest difficulty where this child would still get ~70% right first time", bounded by the per-attempt step limit. The policy sees the hidden ability; the model does not.
5. **Model candidates compared** — ([`train.py`](../ml/math_memory/train.py)) trains three decision trees (depth 4/6/8) and two random forests (depth 6/8), evaluates each on a child-disjoint validation split, and picks the simplest model within 0.005 of the best.
6. **Export + parity test** — the chosen scikit-learn tree ensemble is dumped to a compact JSON format, and a reference Python evaluator over that JSON is checked against scikit-learn for 100% agreement on the test set.
7. **On-device evaluator** — a small Dart implementation of the same evaluator (`TreeEnsembleModel`) is wired into the app. Flutter tests load a fixture of 300 (features, expected class, probabilities) cases per model and assert exact agreement.
8. **Integration** — the next-attempt planner, fallback path, and local-progress storage are wired in. Attempts are queued for sync with the features and prediction attached, so a real-data retrain is possible later.

---

## 5. Training data: the learner simulator

[`simulate.py`](../ml/math_memory/simulate.py) is the heart of the pipeline. It fabricates children with hidden abilities, plays them through the same attempt structure the app runs, and records the observable features alongside the expert label.

### 5.1 Simulated children

Each child is drawn once at the start of their four attempts and has fixed hidden traits for the entire training run.

**Number Quest learners** (`NqLearner`):

| Trait | Range | Meaning |
|---|---|---|
| `ability[skill]` | `general ∈ [0.3, 5.5]` + `SKILL_OFFSET[skill]` + `𝒩(0, 0.7)` | Level the child is comfortable at, per skill. General ability + the skill's typical difficulty + personal variation. |
| `base_rt` | 3–10 s | Time to answer an easy question. |
| `slope` | 1.2–2.4 | How sharply success falls off once the question exceeds their ability. |

The hard-coded `SKILL_OFFSET` encodes typical 7–9-year-old difficulty: `counting` is easiest (+1.0), then `addition` (+0.4), `subtraction` (0.0), `multiplication` (−0.6), and `division` is hardest (−0.9). This is a design choice, not a measurement.

The probability of a first-try correct answer at `level` is `sigmoid(slope · (ability − level + 0.5))`. The 0.5 shift means a child whose ability equals the question's level still answers correctly ≈62% of the time first try — in line with the ~70% target zone.

**Memory Match learners** (`MemoryLearner`):

| Trait | Range | Meaning |
|---|---|---|
| `capacity` | 2.0–9.5 | How many pictures they recall around 50% of the time at 6 s of looking. |
| `time_gain` | 0.1–0.45 | Extra effective capacity per extra second of looking. |
| `base_rt` | 1.5–6 s | Time to the first tap. |
| `slope` | 1.0–2.2 | Steepness of the ability curve. |

### 5.2 Simulated play

For each child the simulator runs 4 attempts: one baseline (attempt 0) and three scored attempts at random starting difficulties. Each activity is answered under the same two-try rule the app enforces:

- First-try success probability: `p_first = sigmoid(slope · (ability − level + 0.5))`.
- If the first try fails, the child picks between the two remaining options with help from residual knowledge: `p_second = 0.5 + 0.4 · p_first` (Number Quest), or `min(0.95, 1/(positions−1) + 0.4 · p_first)` (Memory Match).
- Response times are log-normal around `base_rt · exp(0.3 · (level − ability))`, capped at 90 s.

During scored attempts, the simulator mimics the app's in-attempt rules with a small random drift (15% chance per Number Quest question, 20% per Memory Match round) of ±1 in the active difficulty. This matters: the model must be robust to small within-attempt changes, not just a flat starting setting.

### 5.3 Dataset size

| Dataset | Children | Attempts/child | Rows/attempt | Total rows |
|---|---|---|---|---|
| Number Quest | 4,000 | 4 | 5 (one per skill) | 80,000 |
| Memory Match | 8,000 | 4 | 1 | 32,000 |

Memory Match has twice as many children because it has one row per attempt instead of five; this keeps the two training sets at comparable size per predicted class.

### 5.4 Splits

A single `GroupShuffleSplit` by **child** carves off 30% of children, then another `GroupShuffleSplit` on that 30% halves it into validation and test. The three splits are 70% / 15% / 15% of children, and crucially, **no child appears in two splits**. If children leaked across splits, the model would get credit for memorising a particular child's noisy signature rather than generalising.

---

## 6. Features

All features are defined in [`features.py`](../ml/math_memory/features.py) and mirrored in `app/lib/features/math_memory/ml/next_attempt_features.dart`. The exported model artifact lists `feature_names`; the app checks the names before using the model and falls back to rules on any mismatch. **The two definitions must stay in sync by hand** — this is a known weak point (see [§13](#13-limitations)).

### Number Quest — one row per skill asked in the attempt

| Feature | Meaning |
|---|---|
| `is_baseline` | 1.0 if the attempt was the first (ungraded) baseline, else 0.0 |
| `ref_level` | Reference level the delta is measured from. **Baseline:** the highest level the skill was asked at (2 for Number Quest's `(1, 2)` baseline plan). **Scored:** the skill's starting level. |
| `mean_level` | Mean level of the questions actually asked |
| `n_questions` | Number of questions asked for the skill in this attempt |
| `first_try_acc` | Share of questions correct on the first try |
| `eventual_acc` | Share correct on either try |
| `hint_rate` | Share that required a second try (a hint was shown) |
| `mean_rt_s` | Mean time to the first answer, in seconds, capped at 60 |
| `max_miss_streak` | Longest run of non-first-try answers in a row |

### Memory Match — one row per attempt

| Feature | Meaning |
|---|---|
| `is_baseline` | 1.0 for the ungraded baseline attempt |
| `ref_rung` | Ladder rung the delta is measured from. **Baseline:** rung 3 (`(4 pictures, 6 s)` — the middle of the baseline plan). **Scored:** the rung nearest the first round's `(pictures, seconds)` |
| `mean_positions` | Mean picture count across the attempt |
| `mean_seconds` | Mean looking time |
| `first_try_acc` | Share of rounds recalled first try |
| `eventual_acc` | Share correct on either try |
| `wrong_per_round` | Average number of wrong card taps per round |
| `mean_rt_s` | Mean time to first tap, capped at 60 |
| `max_miss_streak` | Longest miss streak |
| `largest_board_first_try_acc` | First-try accuracy restricted to the biggest board size seen in the attempt |

The last feature is a useful detail: if the child saw mostly small boards and one 7-picture board, the one row of 7-picture data is the strongest signal of their actual ceiling. Averaging it into the overall accuracy would wash out that signal.

### Choice of reference

Measuring the delta from `ref_level`/`ref_rung` rather than, say, `mean_level`/`mean_positions` is deliberate: the next attempt will **start** at the reference, so a delta against the reference is a direct instruction. The baseline's reference uses "highest level asked" (NQ) and "middle rung" (MM) so a child who maxes out the baseline still has somewhere to climb next time.

### Feature engineering decisions

- **Capping `mean_rt_s` at 60 s.** Response time is log-normal and occasionally very long (a distracted child); the cap keeps a single huge value from dominating the mean.
- **`eventual_acc` as well as `first_try_acc`.** The gap between the two is a surrogate for "could they have known it with a hint", which matters when deciding whether to go up or stay.
- **No child-identity feature.** Every row is independent of child identity. Within-child trends are not modelled by design — the between-attempt model sees only one attempt at a time, like a tutor who meets each child fresh.

---

## 7. Labels: the expert policy

Each simulated attempt is labelled with the difficulty an expert would pick **if they could see the child's hidden ability**.

> **The hardest difficulty at which the child would still get about 70% right on the first try**, limited to a small step from the current reference difficulty.

- **Number Quest** per-skill target: `clip(ideal_level, ref_level ± 1, 1 ≤ · ≤ 5)`. The label is `target − ref_level ∈ {−1, 0, +1}`.
- **Memory Match** target: `clip(ideal_rung, ref_rung ± 2, 0 ≤ · ≤ 10)` after a scored attempt, or `± 3` after the baseline (where the baseline rung is a fixed anchor and a bigger first move is safer). The label is `target − ref_rung ∈ {−3, …, +3}`.

The 70% threshold operationalises the "zone of proximal development" idea: challenging enough to stretch, achievable enough to keep motivation. The step bound encodes the pedagogical constraint that difficulty should **never jump**; one attempt is not enough evidence to leap several levels at once.

**The model never sees the hidden ability.** Its only inputs are the observable features from one noisy attempt. The whole learning problem is: *infer the expert's ability-aware choice from the ability-blind evidence of a single attempt.*

---

## 8. Model candidates and training procedure

Five candidate models are trained per dataset, all tree-based:

| Candidate | Algorithm | Depth | Trees | Min samples per leaf | Class weight |
|---|---|---|---|---|---|
| `decision_tree(depth=4)` | `DecisionTreeClassifier` | 4 | 1 | 25 | `balanced` |
| `decision_tree(depth=6)` | `DecisionTreeClassifier` | 6 | 1 | 25 | `balanced` |
| `decision_tree(depth=8)` | `DecisionTreeClassifier` | 8 | 1 | 25 | `balanced` |
| `random_forest(trees=30,depth=6)` | `RandomForestClassifier` | 6 | 30 | 25 | `balanced` |
| `random_forest(trees=30,depth=8)` | `RandomForestClassifier` | 8 | 30 | 25 | `balanced` |

### Why these choices

- **Tree-based.** We need a model that is small, fast, and trivially portable to Dart with no external runtime. Trees fit on a few kilobytes of JSON and evaluate in microseconds. Linear models were considered but ruled out: the signal is interaction-heavy (`first_try_acc` matters differently depending on `is_baseline` and `mean_rt_s`), which is exactly where trees shine over linear boundaries.
- **Balanced class weights.** The baseline attempts naturally produce an imbalance (most children land near "stay" after a baseline). Balanced weighting avoids a trivial model that always predicts 0.
- **`min_samples_leaf = 25`.** Reduces noise sensitivity and keeps the exported JSON compact.
- **Three depths for single trees, two for forests.** Enough to see over- and under-fitting on validation; more would just add noise to the comparison.
- **30 trees in forests.** A good small-model trade-off: more trees barely improved validation accuracy but doubled artifact size.

### Selection rule

For each dataset we fit all five candidates on the training split, score them on the validation split, and pick the **simplest candidate within 0.005 of the best validation accuracy**. In practice this means decision trees are preferred over random forests when they're close, and shallower trees over deeper ones when they're close. The rule is explicit in `train.py`:

```python
best_acc = max(r[0] for r in results)
val_acc, chosen_label, chosen = next(r for r in results if r[0] >= best_acc - 0.005)
```

### Chosen models (v1.0.0)

| Model | Validation accuracies | Chosen |
|---|---|---|
| Number Quest | DT4 0.764, DT6 0.792, DT8 0.787, RF6 0.791, RF8 0.794 | **DT depth 6** (within 0.005 of best, simpler) |
| Memory Match | DT4 0.719, DT6 0.729, DT8 0.727, RF6 0.734, RF8 0.739 | **RF 30 × depth 8** (clear best, no simpler model within tolerance) |

### Refit and test

Once the candidate is chosen, it's refit on **train + validation** (so no training data is wasted on model selection) and scored **once** on the untouched test split. We never iterate against test metrics; those are the honest estimate of generalisation on the simulated population.

---

## 9. Evaluation

Full numbers live in [`ml/math_memory/reports/evaluation.md`](../ml/math_memory/reports/evaluation.md). Measured on the held-out, child-disjoint test split.

### 9.1 Metrics

| Metric | What it measures |
|---|---|
| `accuracy` | Share of attempts where predicted class == expert class |
| `macro_f1` | F1 averaged across classes (fairer when classes are imbalanced) |
| `mean_abs_error_steps` | Average `|predicted − expert|` in levels/rungs |
| `within_one_step` | Share of predictions within one step of the expert |
| `too_hard_rate` | Share where prediction > expert (child gets a harder-than-ideal next attempt) |
| `too_easy_rate` | Share where prediction < expert |
| `accuracy_after_baseline` / `accuracy_after_scored` | Accuracy split by attempt type |

`too_hard_rate` matters most for user experience: a too-hard next attempt is the thing most likely to demotivate a 7-year-old with dyslexia. We deliberately watch this separately from accuracy.

### 9.2 Baselines

Two reference strategies are evaluated on the same test split:

- **`stay`.** Always predict 0 (keep same difficulty). The lower bound.
- **`rules`.** A hand-written threshold policy modelled on the app's `rules_v1`. For Number Quest: look at `first_try_acc`, `eventual_acc`, and `mean_rt_s`. For Memory Match: a simple `first_try_acc ≥ 0.83 → +1`, `≤ 0.5 → −1`, else `0`. This is the strongest hand-written baseline we could reasonably write without peeking at the test set.

### 9.3 Headline results (v1.0.0)

**Number Quest — next level per skill**

| | Accuracy | Macro-F1 | MAE (levels) | Within 1 | Too hard | Too easy |
|---|---|---|---|---|---|---|
| **Trained model** | **0.795** | **0.753** | **0.223** | 0.982 | **0.130** | 0.074 |
| Rules baseline | 0.671 | 0.591 | 0.387 | 0.942 | 0.294 | 0.034 |
| Keep same | 0.197 | 0.110 | 0.803 | 1.000 | 0.460 | 0.343 |

Split by attempt type: 0.737 accuracy after a baseline, 0.814 after a scored attempt.

**Memory Match — next ladder rung**

| | Accuracy | Macro-F1 | MAE (rungs) | Within 1 | Too hard | Too easy |
|---|---|---|---|---|---|---|
| **Trained model** | **0.725** | **0.629** | **0.391** | **0.899** | **0.131** | 0.144 |
| Rules baseline | 0.145 | 0.100 | 1.055 | 0.806 | 0.418 | 0.437 |
| Keep same | 0.078 | 0.021 | 1.801 | 0.271 | 0.433 | 0.489 |

Split by attempt type: 0.668 accuracy after a baseline, 0.744 after a scored attempt.

### 9.4 Reading these numbers

- Both models clearly beat both baselines at recovering the expert choice from a single attempt.
- The models are **"too hard" much less often than rules** — 13% vs 29% (NQ) and 42% (MM). This is the single most important win: motivation is fragile at this age.
- Post-baseline accuracy is lower than post-scored, as expected — the baseline provides only two Number Quest questions per skill and six fixed Memory Match rounds, so there is simply less signal.
- The Memory Match rules baseline looks weak partly because it can only move ±1, while the expert policy can move up to ±3 after a baseline; the comparison is not quite like-for-like, which is part of why we moved to a model.

> **These numbers measure agreement with the expert policy on simulated children. They are not evidence of a learning benefit for real children.** See [§13](#13-limitations).

### 9.5 Parity test

On top of the metrics above, the pipeline runs a strict agreement check between scikit-learn's predictions and the exported JSON evaluator across the whole test set:

```python
exported = np.array([predict_from_export(artifact, row)[0] for row in X[te]])
agreement = float(np.mean(exported == test_pred))
assert agreement == 1.0
```

If the exported model and scikit-learn disagree on even one row, the training run fails. This is what gives us confidence that the Dart evaluator (which uses the same arithmetic rules as `predict_from_export`) matches the model that scored 79.5% / 72.5% on test.

---

## 10. Export format and on-device inference

### 10.1 Artifact schema

Each model is exported to a single compact JSON file (`app/assets/models/math_memory/<model_id>.json`). The structure:

```jsonc
{
  "model_id": "number_quest_next_level",
  "model_version": "1.0.0",
  "algorithm": "decision_tree(depth=6)",
  "trained_at": "2026-10-18T…Z",
  "sklearn_version": "1.5.2",
  "seed": 20261018,
  "feature_names": ["is_baseline", "ref_level", …],   // order matters
  "classes": [-1, 0, 1],                              // output label values
  "data": { … },                                      // provenance
  "test_metrics": { … },
  "output": "next level = ref_level + class, clamped to 1..5 (one row per skill)",
  "trees": [
    {
      "feature":   [0, 2, -2, …],                    // -2 = leaf
      "threshold": [0.5, 3.5, -2.0, …],
      "left":      [1, 3, -1, …],                    // -1 = leaf
      "right":     [2, 4, -1, …],
      "value":     [[0.33, 0.34, 0.33], …]           // leaf class probabilities
    },
    …
  ]
}
```

- A **single tree** (Number Quest) → `"trees"` has one element.
- A **random forest** (Memory Match) → `"trees"` has 30 elements, averaged uniformly.
- Values are normalised per leaf (`value / value.sum(axis=1)`), so each row is a proper probability vector.
- Thresholds are rounded only after being cast to Python `float`; see [§10.3](#103-float32-comparison) for the critical float32 note.

### 10.2 Reference evaluator (Python)

[`train.py`](../ml/math_memory/train.py) ships with `predict_from_export`, a 20-line reference implementation of inference over the exported JSON. It is what the parity test runs; it is also the behavioural spec the Dart evaluator must match:

```python
def predict_from_export(artifact, row):
    n_classes = len(artifact["classes"])
    total = [0.0] * n_classes
    for tree in artifact["trees"]:
        node = 0
        while tree["left"][node] != -1:
            x = float(np.float32(row[tree["feature"][node]]))
            node = tree["left"][node] if x <= tree["threshold"][node] else tree["right"][node]
        for k, p in enumerate(tree["value"][node]):
            total[k] += p
    probs = [p / len(artifact["trees"]) for p in total]
    best = max(range(n_classes), key=lambda k: (probs[k], -k))
    return artifact["classes"][best], probs
```

### 10.3 float32 comparison

Trees are notoriously sensitive to exact float comparisons at thresholds. scikit-learn casts inputs to **float32** before comparing. The exported evaluator does the same (`float(np.float32(row[…]))`) and so does the Dart evaluator. Without this cast, roughly 1 in 1,000 test rows disagree at a threshold boundary, which fails the parity assertion.

### 10.4 Dart evaluator (`TreeEnsembleModel`)

The app bundles a small Dart class (`app/lib/features/math_memory/ml/`) that:

1. Loads the JSON once at app start.
2. Validates `feature_names` against the app's own `NextAttemptFeatures` schema and refuses to use a model with mismatched names.
3. For a given feature vector, walks each tree node-by-node using float32 comparison and averages the leaf probability vectors (identical algorithm to `predict_from_export`).
4. Clamps the resulting class delta to the step limit before handing it back to the game.

The Flutter test suite loads **300 cases per model** (`app/test/features/math_memory/fixtures/*_parity.json`), each with a feature vector, expected class, and expected probabilities, and asserts exact equality. This is what guarantees "the model running on the phone is the same model that scored 79.5% on test".

### 10.5 Why not TFLite or ONNX?

TFLite and ONNX runtimes would add ~1–3 MB per Android ABI to the APK, require platform-specific wiring, and buy us nothing for a 6 KB decision tree. The custom evaluator is ~150 lines of Dart, has zero dependencies, and runs in microseconds.

---

## 11. Integration with the app

### 11.1 Lifecycle of a prediction

```
Attempt ends
   │
   ▼
NextAttemptFeatures.from(attempt)   ← same computation as features.py
   │
   ▼
TreeEnsembleModel.predict(features)
   │  ┌─ feature_names mismatch, missing file, or exception?
   │  └─────────────────► fallback = rules_v1 picks delta
   ▼
clamp(delta, step_limit)
   │
   ▼
NextAttemptPlan { source: "model" | "fallback", features, confidences, delta, chosen }
   │
   ├─ Saved to local_learner_progress (Drift) — next attempt opens with this
   └─ Attached to the attempt's result_payload — queued in pending_activity_results
                                                   for sync to POST /activity-results
```

The planner records both the model's choice and what the rules **would have** chosen, plus the confidence vector over all classes. This metadata is pure gold for the eventual real-data retrain (see [§14](#14-path-to-real-learner-data)).

### 11.2 Guardrails

- **Feature schema check.** The planner refuses a model whose `feature_names` don't match the app's own list, in order or value. This catches a mismatched update (e.g. training added a feature but the app wasn't updated) before any wrong prediction can reach a child.
- **Step clamp.** Even if the model mis-predicts the extreme class, the clamp keeps the move within ±1 (NQ) or ±2/±3 (MM).
- **Range clamp.** Next level is clamped to 1–5 (NQ) and 0–10 (MM) regardless of model output.
- **Fallback is total.** Any exception, any load failure, any mismatch → the game runs under rules with no visible effect on the child's experience. The source field (`"fallback"`) records which path was taken.

### 11.3 Where the model is **not** used

- **During an attempt.** Mid-attempt difficulty changes are rule-driven. Three fast first-try wins → up one; two misses in a row → down one, with extra pictures-based practice; and so on. The model acts only between attempts.
- **For the first baseline.** The baseline plan is fixed (`(1, 2)` levels for each NQ skill; the six-round MM plan). The model predicts *after* it to pick where attempt 2 starts.
- **For scoring, stars, or feedback.** None of the user-visible UX depends on the model.

---

## 12. Reproducibility

The pipeline is designed so a reviewer can rebuild bit-identical models from the repo with one command.

### 12.1 Pinned environment

[`ml/math_memory/requirements.txt`](../ml/math_memory/requirements.txt) pins:

- Python 3.12 (via the Docker base image)
- `numpy == 2.1.3`
- `scikit-learn == 1.5.2`

### 12.2 Fixed seeds

- `SEED = 20261018` throughout. Each sub-step (dataset generation, candidate training, train/val/test split) derives its RNG from this seed.
- `GroupShuffleSplit` is given `random_state=SEED` for the outer split and `SEED + 1` for the inner split, so the three splits are stable across runs.

### 12.3 One-command rebuild

From the repo root (no local Python needed):

```sh
docker run --rm -v "$PWD":/repo -w /repo/ml/math_memory python:3.12-slim \
  sh -c "pip install -q -r requirements.txt && python train.py"
```

On Windows Git Bash, prefix with `MSYS_NO_PATHCONV=1` and use `"$(pwd -W)"` instead of `"$PWD"`.

This regenerates:

- `app/assets/models/math_memory/number_quest_next_level.json`
- `app/assets/models/math_memory/memory_match_next_config.json`
- `ml/math_memory/reports/evaluation.{md,json}`
- `app/test/features/math_memory/fixtures/*_parity.json`

The only field that changes between runs is `trained_at`.

### 12.4 Flutter tests

After retraining, run from `app/`:

```sh
flutter analyze
flutter test test/features/math_memory
```

The ML-specific tests cover:

- Loading the models from the bundled assets with no network.
- **Exact** Python/Dart agreement on 600 parity cases (300 per model).
- Predictions always within the step limit.
- Stronger simulated performance → harder next attempt.
- The next attempt actually using the predicted difficulty.
- The fallback path firing cleanly when the model file is missing or malformed.

---

## 13. Limitations

The pipeline is production-quality. The *validity* of the predictions depends on assumptions that have not been tested with real children.

1. **Synthetic training data.** Every assumption in `simulate.py` — the logistic success curve, the 70% target zone, the skill-difficulty offsets, the response-time distribution, the capacity-plus-time-gain memory model, the second-try boost — is a reasoned design choice, not a measurement of real 7–9-year-old dyslexic learners. Real children may behave differently because of fatigue, guessing strategies, language processing, motivation, or domain-specific prior knowledge.
2. **Expert policy is an assumption, not ground truth.** "70% first-try accuracy" operationalises the zone-of-proximal-development idea, but the right target for a child with dyslexia may be lower (less frustration) or higher (more challenge), and the right step limit may be different.
3. **Not a diagnostic tool.** The baseline estimates a comfortable starting difficulty. It is **not** a dyslexia screener, not a reading/numeracy assessment, and no result from this system should be read as a clinical judgement.
4. **Feature definitions exist twice.** [`features.py`](../ml/math_memory/features.py) and `next_attempt_features.dart` must stay in sync by hand. A mismatch triggers the fallback (safe) but silently loses the ML benefit. Codegen from a single source would remove this risk.
5. **In-attempt rules and scoring thresholds are untuned.** The 10/5-point split, the 40/70/90% star thresholds, the "3 fast correct in a row" rule — all sensible defaults, none tested with children.
6. **No per-child personalisation.** Each prediction is made from one attempt's features; the model has no memory of this specific child. Real-data retraining could add child-level features (e.g. recent trend) if warranted.
7. **Progress is kept on the phone only.** The learner-progress endpoint on the backend is not yet wired; the queued activity results carry enough signal to rebuild progress server-side when needed, but the UI's current levels live only in `local_learner_progress`.

---

## 14. Path to real-learner data

The pipeline was explicitly designed to make the eventual retrain on real data a drop-in replacement.

### 14.1 What we already collect

Every completed attempt the app queues (`component_name: math_memory`) includes:

- `features` and, for Number Quest, `skills.*.features` — the exact feature vector the model saw.
- `next_attempt.model` — the model's class delta and confidence vector.
- `next_attempt.source` — whether the choice came from the model or the fallback.
- `next_attempt.rules_choice` — what the rules baseline would have picked.
- The activity-level results of the attempt itself.

Chained across consecutive attempts for the same child, this is sufficient to construct a real-data training set. The natural real-world label becomes: *the setting where the child's **next** attempt landed near 70% first-try*.

### 14.2 Retrain procedure

1. Pull anonymised attempt rows from the backend.
2. Replace the generator functions in `simulate.py` with a loader that yields `(features, label)` from real pairs of consecutive attempts.
3. Keep [`features.py`](../ml/math_memory/features.py) **unchanged** — the whole point of pinning features is that the app's deployed clients already produce them.
4. Re-run `python train.py`.
5. Bump `MODEL_VERSION` in `train.py` (e.g. `1.0.0` → `2.0.0`), so the artifact clearly announces it was trained on real data.
6. Ship a new app build with the new JSON. The on-device evaluator does not need to change.

### 14.3 What we'd want before shipping a real-data model

- Enough rows per class — ideally thousands of consecutive-attempt pairs per combination of `is_baseline` and reference difficulty.
- A review of the 70% target against observed first-try accuracy distributions.
- A pre-registered evaluation plan that compares the new model against the current (v1.0.0) synthetic-trained model on the real test split.
- Child-level privacy review: no identifying features in the training set, k-anonymity on any grouping variable.

---

## 15. Where the code lives

### Training pipeline (Python)

| Path | Purpose |
|---|---|
| [`ml/math_memory/features.py`](../ml/math_memory/features.py) | Feature definitions, difficulty ladder, baseline plans. Shared truth. |
| [`ml/math_memory/simulate.py`](../ml/math_memory/simulate.py) | Synthetic learner simulator and expert labelling policy. |
| [`ml/math_memory/train.py`](../ml/math_memory/train.py) | Dataset generation, splits, candidate training, selection, export, parity check, report writing. |
| [`ml/math_memory/requirements.txt`](../ml/math_memory/requirements.txt) | Pinned numpy and scikit-learn. |
| [`ml/math_memory/reports/evaluation.md`](../ml/math_memory/reports/evaluation.md) | Human-readable evaluation. |
| [`ml/math_memory/reports/evaluation.json`](../ml/math_memory/reports/evaluation.json) | Machine-readable evaluation. |
| [`ml/math_memory/README.md`](../ml/math_memory/README.md) | Quickstart for the training pipeline. |

### App (Dart / Flutter)

| Path | Purpose |
|---|---|
| `app/assets/models/math_memory/number_quest_next_level.json` | Bundled Number Quest model. |
| `app/assets/models/math_memory/memory_match_next_config.json` | Bundled Memory Match model. |
| `app/lib/features/math_memory/ml/next_attempt_features.dart` | Dart twin of `features.py`. |
| `app/lib/features/math_memory/ml/` | `TreeEnsembleModel`, next-attempt planner, fallback bridge. |
| `app/lib/features/math_memory/engine/` | Shared attempt types, scoring, rules engine (`rules_v1`). |
| `app/lib/features/math_memory/data/` | Local progress storage (Drift) and result queueing. |
| `app/test/features/math_memory/fixtures/*_parity.json` | 300 (features, class, probabilities) cases per model. |
| `app/test/features/math_memory/` | Flutter tests, including the ML parity test and fallback test. |

### Related docs

| Path | Purpose |
|---|---|
| [`docs/maths-cognitive-learning.md`](maths-cognitive-learning.md) | User-facing overview of the Math & Memory section. |
| [`docs/api-contract.md`](api-contract.md) | `POST /activity-results` payload schema; the ML metadata rides on top. |
| [`docs/decision-log.md`](decision-log.md) | Design decisions, including the move from rules to a trained model. |

---

## 16. Glossary

- **Attempt.** One sitting of a game: the baseline attempt (first time) or a scored attempt (every time after).
- **Baseline attempt.** The first attempt in a game. Fixed set of questions/rounds, ungraded, invisible to the child as a "test".
- **Scored attempt.** Any attempt after the baseline. Adaptive, with points, percentage, and 0–3 stars.
- **Level** (Number Quest). Integer 1–5 per skill, controlling the numerical range and whether questions are shown with pictures or abstract blocks.
- **Rung** (Memory Match). Integer 0–10 along the `(pictures, seconds)` difficulty ladder; neighbouring rungs differ in exactly one factor.
- **Reference difficulty** (`ref_level` / `ref_rung`). The level/rung the predicted delta is measured from.
- **Delta.** The signed step the model predicts (−1/0/+1 for NQ; −3…+3 for MM).
- **Expert policy.** The ability-aware labelling rule in `simulate.py` that the model is trained to reproduce from ability-blind evidence.
- **`rules_v1`.** The hand-written rules engine in the app, used for in-attempt tuning and as the fallback when the model is unusable.
- **Parity test.** The strict equality check between scikit-learn's predictions, the Python reference evaluator, and the Dart on-device evaluator.
- **`is_baseline`.** The 1.0/0.0 feature that tells the model which attempt type it's reasoning about. Flipping it generally shifts predictions down (more conservative after a baseline, which carries less signal).
