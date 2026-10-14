# ml/speech — Speech & Pronunciation Assessment

Reference-voice-based speech and pronunciation assessment with gamified phoneme-level remediation
for Sinhala–English bilingual children (Grades 2–3). This is a practice/assessment aid, **not a
diagnostic or clinical tool**.

Pipeline: audio → 16 kHz mono → XLS-R (`facebook/wav2vec2-xls-r-300m`) layer embeddings → DTW against
a multi-reference bank → acceptance range learned from the bank (leave-one-out) → akshara-level
localisation → Detect → Localise → Isolate → Drill → Reconnect remediation loop.

## Setup

```sh
cd ml/speech
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt   # Windows; use .venv/bin/python on Linux/macOS
```

For tests only, the light set is enough: `numpy scipy pyyaml pytest black`.

## Run

```sh
python scripts/make_synthetic_bank.py        # writes data/ (gitignored): words.csv, reference/*.json, embeddings/*.npy
python -m pytest                             # from ml/speech; no network or model download needed
python -m black --check .
```

## Data rules

- `data/` is **gitignored**, as are all `*.wav` / `*.npy` files under `ml/speech`. Never commit audio,
  embeddings, bank manifests or personal data.
- During development, use only synthetic data (`make_synthetic_bank.py`) or adult sample clips.
  Children's recordings are collected only after ethics clearance.

## Status

| Stage | Status |
|---|---|
| 0 Setup | Done |
| 1–7 | Not started |

### Tested
- `src/scoring.py` (reference implementation, logic unchanged, Black-formatted only):
  `tests/test_scoring.py`. Multi-reference accepts the accent variant and rejects the wrong sound,
  a single reference wrongly penalises the variant, and localisation flags the 2nd sound.
  Same data, seed and asserts as the original script, wrapped in pytest functions.
- `tests/test_scoring_on_bank.py`: the on-disk bank format (seconds → frames) works with `scoring.py`.
  The same word scores lower than a different word, and swapping the middle akshara of කමල makes
  localisation flag ම.
- `scripts/make_synthetic_bank.py`: layout, shapes, contiguous unit boundaries, determinism, and that
  frames carry unit identity (`tests/test_synthetic_bank.py`).

### UNTESTED / placeholders
- The threshold in `tests/test_scoring.py` is computed from the very scores it then checks. That is
  fine as a sanity demo, but it is not evidence of real accuracy. The learned leave-one-out range comes in Stage 3.
- `dtw` is pure-Python O(n·m). It is fast enough for tests, but its latency on real ~6 s utterances is unmeasured.
- `config/settings.yaml`: `layer: 12`, `trim_top_db`, `fallback_threshold: 0.30` are placeholders,
  chosen later on DEV data only.
- `config/confusions.yaml`: TO VALIDATE WITH SPEECH-LANGUAGE EXPERT.
- `requirements.txt`: only numpy/scipy/pyyaml/pytest/black have been installed and run so far.

## Open questions
- Team sign-off on adding shared gen-l10n (Stage 1) and the drift `AppDatabase` schema bump 2→3 for
  `pending_speech_recordings` (Stage 6).
- Card IDs for speech rewards (the catalog is opaque strings for now).
