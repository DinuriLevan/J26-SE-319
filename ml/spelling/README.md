# Spelling difficulty classifier (FR4)

From one word's interaction log, predict how hard that phonics skill currently
is for the child: **easy / medium / hard**. The app uses the prediction to set
how hard the next focus words are.

## How it fits in the app

| Part | Job | Requirement |
|---|---|---|
| **BKT** (`engine/learner_model.dart`) | Keeps the learner profile: mastery of each skill for this child | FR5 |
| **Trained classifier** (this folder → `model/difficulty_classifier.dart`) | From the child's behaviour on a word, predicts how hard that skill is right now | FR4, Table 1 |
| **Selector** (`engine/selector.dart`) | BKT picks WHICH skill; the classifier picks HOW HARD (hard → difficulty 1, medium → 2, easy → 3, averaged over the last 3 predictions) | FR6 |

The classifier runs fully offline: the trained model is converted to plain Dart
code with m2cgen. No server, no TensorFlow. If the model files are missing or
fail, the app falls back to the old BKT rule and marks predictions `fallback`.

## The pipeline (run in this order)

`data/` starts empty: the simulated CSVs are not kept in git (step 1 recreates them identically in
about 40 seconds), and pilot data must stay private. The trained model is already in the app, so you
only need these steps to retrain.

```powershell
cd ml\spelling
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt

python spell_simulate.py                         # 1. simulated children → data/sim_features.csv (+ control set)
python spell_label.py data/sim_features.csv      # 2. labels → data/sim_labelled.csv
python spell_label.py data/sim_control_features.csv
python spell_train.py data/sim_labelled.csv --tag sim                  # 3. 6 combinations, grouped CV
python spell_train.py data/sim_control_labelled.csv --tag sim_control
python spell_evaluate.py --tag sim --control-tag sim_control --data data/sim_labelled.csv   # 4. Table 1, A vs B, SHAP
python spell_export.py --data data/sim_labelled.csv                    # 5. model → app (Dart) + parity test
```

| Script | What it does |
|---|---|
| `spell_simulate.py` | 200 simulated children × 12 rounds with hidden weak skills, a personal speed, a b/d tendency, left-out letters in blends, and learning over time. Writes the **same columns as the app's features CSV**, and the hidden truth. Also writes a **control set** where hesitation, corrections and replays are random (no behaviour signal). |
| `spell_label.py` | Label = how the child does on their **next 3 words of the same skill**: all right first time → easy; 2 or more not right first time → hard; else medium. Rows with fewer than 2 future words are dropped. |
| `spell_features.py` | Feature set **A** (correctness only) and **B** (A + behaviour), written as "recipes" so the app can rebuild exactly the same vector. |
| `spell_train.py` | Logistic Regression, Random Forest, XGBoost × A/B. Grouped 5-fold CV by child (no child in both train and test), repeated 3× with different splits; small grid search inside the training folds only. |
| `spell_evaluate.py` | Table 1 (accuracy, macro precision / recall / F1, mean ± std), confusion matrices, per-class report, paired Wilcoxon A vs B, SHAP plot for the best model, the same for the control set. |
| `spell_export.py` | Retrains the best model on all data, exports it to Dart (m2cgen), writes `feature_order.json` and `preprocessing.json` into the app, and runs the Dart parity test (same class and probabilities as Python on 50 rows). |
| `spell_predictions.py` | Shows what the classifier currently thinks about each child (label, how sure, ml/fallback, BKT), from the app's **Model state JSON** export. `--csv out.csv` saves the table. |

Shared helpers are in `spell_common.py` (paths, column names, a copy of the app's BKT update).
All scripts are named `spell_*` so they don't clash with other members' files.

## Retraining on real pilot data

1. In the app: **Teacher View → ⋮ menu → Word data (CSV)** on each test device.
   The files are in `Android/data/com.akurin.akurin/files/spelling_exports/`
   (copy with a USB file browser or `adb pull`).
2. Merge them into one file and save it as `data/pilot_features.csv`
   (any name that does **not** start with `sim_`; result files are then labelled as pilot data).
   Keep only children whose parents gave consent; child ids are already anonymous.
3. Run (about 20 seconds — trains only the chosen model, XGBoost with feature set B):
   ```powershell
   python spell_label.py data/pilot_features.csv
   python spell_export.py --data data/pilot_labelled.csv
   ```
   Only when you need Table 1 / the A-vs-B test for the dissertation, run the full comparison
   first (slow, ~20+ minutes): `python spell_train.py data/pilot_labelled.csv --tag pilot`, then
   `python spell_evaluate.py --tag pilot --control-tag none --data data/pilot_labelled.csv`.
4. Rebuild the app (`flutter run` / `flutter build apk`). The new model is inside it.
5. Commit `ml/spelling/results/best_model.json`, the new `difficulty_model_m2cgen.dart`, `assets/spelling/model/*.json`
   and the parity fixture. Don't commit raw pilot CSVs if they must stay private.

**Enough data?** Labels need at least 2 later words of the same skill, so short pilots lose
many rows. Aim for each child playing several sessions. With fewer than ~30 children, report the
cross-validated numbers with their spread and treat them as preliminary.

## Notes and limits

- Simulated results only show that the pipeline works end to end. Every result file is marked
  "SIMULATED DATA — pipeline validation only. Final results will come from pilot data."
- The simulated children follow the assumptions in `spell_simulate.py` (e.g. weak skills are slower).
  The control set checks that the pipeline does not invent a benefit from behaviour when there is none.
- XGBoost is pinned to 1.7.6 and trained with `num_parallel_tree=1, base_score=0.5, tree_method="exact"`:
  m2cgen cannot export newer XGBoost multiclass models, and reproduces "hist" trees wrongly.
  `spell_export.py` refuses to export if the generated code differs from the model by more than 1e-6.

## Sinhala audio (recorded)

The Sinhala game plays recordings made by a person; there is no text-to-speech. They live in
`app/assets/spelling/sinhala/audio/`: the 300 words (`SI0001.wav` …), the 20 spoken prompts
(`prompts/listen.wav` …) and the sound of every letter and akshara (`tiles/0DB4.wav` = ප,
`tiles/0DB4-0DD6.wav` = පූ). Pillas have no sound. `.wav`, `.m4a` and `.mp3` all work.

```powershell
cd ml\spelling
.venv\Scripts\activate
python spell_si_audio.py               # checks every recording is there (and lists unused files)
python spell_si_audio.py --checklist   # data/si_recording_list.csv: file names + what to say (Excel)
```

To re-record one: save it under the same name in the same folder (e.g. Audacity → Export
Selected Audio → WAV, mono; Effect → Normalize keeps them equally loud), then rebuild the app
(`flutter run`). If a word or prompt is added, run the checker to see which file is missing.
The prompt texts are in `app/lib/features/spelling/sinhala/services/sinhala_voice.dart`.
