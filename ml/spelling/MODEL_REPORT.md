# Spelling & Phonics — model report

Component: AI-Based Adaptive Multilingual Spelling and Phonics Learning (English part).
Covers the learner model (BKT), the trained difficulty classifier, the selector, and how the
game collects the data they use.

> All model results below come from **SIMULATED DATA — pipeline validation only. Final results
> will come from pilot data.**

---

## 1. Answer line: children can now leave out or add letters

**Problem.** The game used to show one box per letter, so a child could never leave a letter out
("fis" for "fish") or add one ("froog" for "frog"). Those are typical dyslexic spelling mistakes,
but the omission and insertion counts were almost always zero.

**What changed in the game**

| Before | Now |
|---|---|
| A fixed row of boxes, one per letter | An open answer line with no box count. It grows when a letter is added and shrinks when one is taken off |
| A letter could only go into an empty box | A letter can be dropped at either end or **between two letters**. A gap opens under the finger to show where it will go |
| ✓ only when every box was filled | ✓ as soon as one letter is on the line, so shorter or longer answers can be checked |
| Tray: the word's letters + 2 distractors | The word's letters + 2–3 distractors (keeping the b/d, p/q mirror rule) + **one extra copy** of a letter in the word (a vowel if possible), so doubling is possible |
| After a wrong try, letters in the wrong box went back | Letters that fit the word **in order** stay (longest common subsequence). "fis" stays as "fis"; one "o" of "froog" goes back |

Unchanged: tap a tile to hear its sound, 3 tries, gentle feedback, voice-first, big tiles.
The demo animation now shows the line too. Checked on the emulator: dragging onto the line,
inserting between letters, checking with 2 letters, and the celebration all work.

**New features in each word's row (FR2):** `n_insertions`, `n_deletions`, `n_replacements`
(a letter taken off and a different one put in the same place), `n_reorders`, `distractor_picks`
(a letter not in the word placed at any time), `answer_length_diff` (first answer length − word length),
and `paused_ms`. Motor slips (a letter picked up again within 1 s) are not counted as edits.

**Paused time is excluded.** The event clock stops when the app goes to the background, when
the child switches tab, or when an adult screen is opened. PAUSE / RESUME events are logged,
and no timing feature includes paused time.

**Tests.** A play-level test drives the game: "fis" for *fish* is producible and is classified
as an omission plus a target-sound error. "froog" for *frog* is classified as an insertion.

**Omission / insertion counts are no longer zero.** With fixed boxes every answer had the word's
length, so these counts were 0 by construction. In a simulated run (200 children × 12 rounds,
24 000 words) there were **886 words with an omission** and **586 with an insertion**. An app test
checks the in-app simulator produces both too.

---

## 2. Three parts, each with one job

| Part | Job | Requirement |
|---|---|---|
| **BKT** (`engine/learner_model.dart`) | Keeps the learner profile: the chance the child knows each skill | FR5 |
| **Trained classifier** (`model/difficulty_classifier.dart` + generated `difficulty_model_m2cgen.dart`) | From the child's behaviour on a word, predicts how hard that skill **currently** is: easy / medium / hard | FR4, Table 1 |
| **Selector** (`engine/selector.dart`) | Picks the next 10 words using both | FR6 |

**How they connect, after every word:**
1. The word's events become a feature row (correctness, mistakes, timing, edits).
2. BKT updates that skill's mastery.
3. The classifier predicts easy / medium / hard for the skill. The prediction is kept with the
   child (last 3 per skill, with a time stamp) and written into the row (`clf_label`, `clf_p_hard`,
   `clf_source`).

**When the next round is planned:**
- **BKT decides WHICH skill** to focus on (unchanged).
- **The classifier decides HOW HARD** the focus words are, from the average of its last 3
  predictions: hard → difficulty 1, medium → 2, easy → 3.
- **Disagreement rule.** If BKT says mastered but the classifier said hard twice in a row,
  the skill is **not** shown as mastered yet, and the next round adds 2 review words of it.
- **Fallback.** If the model file is missing or fails, the old rule is used (the BKT estimate:
  < 45 % hard, < 70 % medium, else easy) and the prediction is marked `source = "fallback"`.
- **Comparison switch.** The setting `useClassifier` (default ON; OFF = old rule) is kept in the
  saved settings so both versions can still be compared. The in-app Research screen was removed,
  so it is no longer shown in the app.
- **Where to see it.** Every prediction is saved with the child and in each word row. Export
  them from **Teacher View → ⋮ menu → Model state (JSON)** or **Word data (CSV)**. The selector's
  reason (e.g. *"BKT 0.38; classifier: hard (0.71) → difficulty 1"*) is saved with every round.

The classifier runs **offline**: the trained model is plain Dart code generated with m2cgen.
There is no server and no ML library on the phone.

---

## 3. The classifier

**Label.** For each word, look at the same child's **next 3 words of the same skill**:
- all right on the first try → **easy**;
- 2 or more not right first time → **hard**;
- otherwise → **medium**.

Rows with fewer than 2 future words are dropped. On the simulated data this left 17 726 rows:
9 475 easy, 5 056 medium, 3 195 hard.

**Feature sets.**
- **A (correctness only):** final_correct, correct_first_try, attempts, error-type counts,
  edit_distance, skill (one-hot), skill_stage, difficulty, word length, has_bdpq, BKT mastery
  before the word.
- **B (A + behaviour):** A plus hesitation_ratio, pause_ratio, log first_input_ms, log total_ms,
  corrections, motor_slips, replays, n_insertions, n_deletions, n_replacements, n_reorders,
  distractor_picks, answer_length_diff.

**Validation.**
- **Grouped by child:** 5-fold cross-validation, so no child is in both training and test.
- **Repeated:** 3 times with different child splits, giving 15 paired folds. With only 5 folds
  a Wilcoxon test can never reach p < 0.05.
- **Tuning:** a small grid search runs inside the training folds only.
- **Class balance:** classes are balanced with class weights.

### Table 1 — SIMULATED DATA (pipeline validation only)

| Model | Features | Accuracy | Macro precision | Macro recall | Macro F1 |
|---|---|---|---|---|---|
| Logistic Regression | A (correctness) | 0.522 ± 0.017 | 0.465 ± 0.013 | 0.498 ± 0.015 | 0.468 ± 0.013 |
| Logistic Regression | B (+ behaviour) | 0.544 ± 0.015 | 0.499 ± 0.011 | 0.518 ± 0.016 | 0.506 ± 0.012 |
| Random Forest | A (correctness) | 0.535 ± 0.018 | 0.473 ± 0.014 | 0.507 ± 0.016 | 0.480 ± 0.015 |
| Random Forest | B (+ behaviour) | 0.575 ± 0.023 | 0.518 ± 0.018 | 0.522 ± 0.019 | 0.516 ± 0.019 |
| XGBoost | A (correctness) | 0.541 ± 0.016 | 0.492 ± 0.013 | 0.517 ± 0.015 | 0.500 ± 0.013 |
| **XGBoost** | **B (+ behaviour)** | 0.549 ± 0.018 | 0.515 ± 0.014 | 0.525 ± 0.016 | **0.519 ± 0.014** |

Mean ± std over 15 grouped test folds. A three-class guess would score about 0.33 macro F1.
Predicting the *next* three words is hard because a child's answers are noisy, so the absolute
numbers are modest. The comparison between A and B is the research question.

### A vs B — does behaviour help? (SIMULATED)

| Model | F1 A | F1 B | B − A | B better in | Wilcoxon p |
|---|---|---|---|---|---|
| Logistic Regression | 0.468 | 0.506 | +0.038 | 15/15 folds | 0.0001 |
| Random Forest | 0.480 | 0.516 | +0.036 | 15/15 folds | 0.0001 |
| XGBoost | 0.500 | 0.519 | +0.018 | 15/15 folds | 0.0001 |

Adding behaviour improves every model, in every fold.

### Control set — behaviour is random noise (SIMULATED)

The same children were simulated, but hesitation, corrections, replays and pauses are random and
unrelated to difficulty. Adding behaviour should then not help, and must not hurt.

| Model | F1 A | F1 B | B − A | p (B worse) | Result |
|---|---|---|---|---|---|
| Logistic Regression | 0.474 | 0.472 | −0.002 | 0.084 | no significant drop ✔ |
| Random Forest | 0.475 | 0.475 | 0.000 | 0.598 | no change ✔ |
| XGBoost | 0.497 | 0.491 | −0.006 | 0.003 | **small but significant drop** ✘ |

So the pipeline does **not** invent a benefit: with noise, B is never better. XGBoost does lose
0.006 F1 when given 13 useless columns. It picks up chance patterns, and extra regularisation
did not remove it. This is a small penalty, and the pipeline guards against it: the model to
ship is chosen by cross-validated F1. On the control data that choice is XGBoost with **set A**,
so useless behaviour features would not be shipped. If behaviour turns out to carry no signal in
pilot data, the same will happen.

**Most important features** of the chosen model (mean |SHAP|):
1. BKT mastery before the word;
2. log total time;
3. hesitation ratio;
4. word length;
5. pause ratio;
6. skill stage;
7. log first-input time.

Three of the top five are behaviour features. (The result files and plots were not kept; running
`spell_train.py` and `spell_evaluate.py` recreates them in `results/`.)

**Model in the app.** XGBoost, feature set B (max_depth 2, min_child_weight 10, reg_lambda 10),
trained on all 17 726 rows and exported to Dart. **Parity test:** on 50 sample rows, Python and
Dart give the same class every time, and probabilities differ by at most 2.2 × 10⁻⁷.

Technical notes:
- XGBoost is trained with `tree_method="exact"` because m2cgen reproduced the faster "hist"
  trees with up to 0.04 probability error.
- The export refuses to write a model whose generated code differs by more than 10⁻⁶.

---

## 4. Retraining on real pilot data (the exact steps)

You do **not** need to re-run the 6-model comparison to update the app. That comparison is only
needed when you want Table 1 for the dissertation.

**Quick update (about 20 seconds): train the chosen model on new data and put it in the app**
```powershell
cd ml\spelling
.venv\Scripts\activate
# 1. In the app on each device: Teacher View → ⋮ menu → Word data (CSV).
#    Copy the files from Android/data/com.akurin.akurin/files/spelling_exports/
#    (USB or adb pull), merge them, save as data\pilot_features.csv
#    (any name NOT starting with sim_, so results are labelled as pilot data).
python spell_label.py data/pilot_features.csv          # 2. add easy/medium/hard labels
python spell_export.py --data data/pilot_labelled.csv  # 3. train XGBoost-B, export to the app, parity test
# 4. Rebuild the app (flutter run / flutter build apk).
```
Use `--retune` on step 3 to re-pick the model settings with a small grid search (a few minutes).

**Full comparison for the dissertation (Table 1, A vs B): slow, run once**
```powershell
python spell_train.py data/pilot_labelled.csv --tag pilot        # 6 models × 15 folds, uses all CPU cores
python spell_evaluate.py --tag pilot --control-tag none --data data/pilot_labelled.csv
python spell_export.py --data data/pilot_labelled.csv            # ships the best model it found
```
This took about 22 minutes for 18 000 rows on 20 CPU cores. Most of the time goes to the exact
XGBoost trees.

**Before trusting pilot results:**
- only include children with consent;
- check each child played several sessions, because labels need 2+ later words of the same skill;
- with fewer than about 30 children, treat the numbers as preliminary.

---

## 5. Earlier learner-model fixes (for reference)

- Warm-up words now count toward each skill's "seen" total.
- Starting guesses are kept separate from real evidence.
- Mastery needs a know-it chance of at least 85 %, at least 5 words, and at least 2 rounds.
- A right answer after a mistake now counts only a little.
- A mistake outside the target sound counts only weakly against the skill.
- Remediation comes first, with at most 2 rounds in a row on the same skill.

Chosen BKT settings, from a simulated parameter sweep: pLearn 0.05, pSlip 0.10, guess chance by
word length × 1.2, fluent start under 1.2× the child's usual time.
