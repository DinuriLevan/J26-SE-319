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
.venv/Scripts/python -m pip install torch==2.5.1 --index-url https://download.pytorch.org/whl/cpu
.venv/Scripts/python -m pip install -r requirements.txt   # Windows; use .venv/bin/python on Linux/macOS
```

## Tests

```sh
python -m pytest            # from ml/speech; no network or model download needed
python -m black --check .
```

## Demo (Stage 1): record references → run service → app

1. For each word in `config/words.csv`, put one or more **adult** reference clips at
   `data/reference/<word_id>/<speaker_id>.wav`. Each clip needs a sibling `<speaker_id>.json`:
   `{"speaker_id": "spk_adult_01", "age_group": "adult", "accent": "standard", "units": []}`
   (`units` can stay empty until Stage 4). Stage 1 uses the first adult reference by `speaker_id`,
   or the one set in `baseline.reference_speaker` in `config/settings.yaml`.
2. `python scripts/build_embeddings.py`. The first run downloads XLS-R (~1.2 GB) to the HuggingFace cache.
3. `uvicorn src.service:app --port 8001`. This loads the model once and runs a warm-up inference.
   Interactive docs are at http://localhost:8001/docs.
4. Backend: `docker compose up --build` (the rebuild installs `httpx`). Inside Docker, the backend reaches
   the service at `http://host.docker.internal:8001`; override this with `SPEECH_SERVICE_URL`.
5. App: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`, then open the Speech tab.

`SPEECH_EMBEDDER=spectral` runs the service with the model-free stand-in embedder. The bank must then be
built with `--embedder spectral`; the service refuses to start on a mismatch. Use it for development only.

## Data rules

- `data/` is **gitignored**, as are all `*.wav` / `*.npy` files under `ml/speech`. Never commit audio,
  embeddings, bank manifests or personal data.
- During development, use only synthetic data (`make_synthetic_bank.py`) or adult sample clips.
  Children's recordings are collected only after ethics clearance.

## Status

| Stage | Status |
|---|---|
| 0 Setup | Done |
| 1 Baseline | Done: single adult reference + fallback threshold; Flutter record → result |
| 2 Layer sweep | Done: layer 9 chosen on dev children; truncated encoder verified and enabled |
| 3–7 | Not started |

## Child corpus (Stage 2)

Ethics approval confirmed 2026-10-15. Recordings live in `data/grade*` (gitignored).

```sh
python scripts/build_child_corpus.py   # -> data/corpus/utterances.csv (anonymous speaker ids, dev/test split by speaker)
python scripts/align_words.py          # -> data/corpus/words.csv (MMS forced-aligned word boundaries)
python scripts/export_spotcheck.py     # -> data/corpus/spotcheck/*.wav + spotcheck.csv to check cuts by ear
python scripts/layer_sweep.py          # -> eval/results/layer_sweep_dev.{csv,md,png}  (dev speakers only)
python scripts/verify_truncation.py    # -> eval/results/truncation_check.json
```

### Tested (automated)
- `tests/test_scoring.py`: the reference implementation `src/scoring.py` (logic unchanged). Multi-reference
  accepts the variant and rejects the wrong sound, a single reference penalises the variant, and
  localisation flags the 2nd sound.
- `tests/test_scoring_on_bank.py`: the on-disk bank format works with `scoring.py`.
- `tests/test_synthetic_bank.py`: the synthetic bank generator.
- `tests/test_audio.py`: resampling 44.1 kHz stereo to 16 kHz mono, silence trimming, and rejecting
  too-long, silent and non-audio input.
- `tests/test_service.py`: `/assess` end to end with tone "words" and `SpectralEmbedder`. Correct word
  accepted, wrong middle unit sent to remediation, 404/422/400 errors, and refusal of a bank built by
  another embedder.
- Backend `backend/tests/test_speech_router.py`: proxy pass-through and error mapping, with the service mocked.
- Flutter `app/test/features/speech/speech_test.dart`: API parsing and error mapping, and the result
  screen in en/si with no "wrong/fail" wording.

- `tests/test_dtw_fast.py`: the numba DTW gives identical costs and paths (including ties) to `scoring.dtw`.
- `tests/test_corpus.py`: corpus indexing (ids, labels, split, Sinhala ZWJ fix) and the dev-only guard;
  the layer sweep drops test speakers and only pairs tokens across different children.

### Stage 2 results (2026-10-15, dev speakers g3_s1, g3_s3, g4_s1, g4_s2)
- Layer sweep over 922 word tokens (335 word types), 20,576 pairs: **layer 9 is best** (AUC 0.984,
  P@1 0.979). Layers 8–13 form a plateau (0.981–0.984); the last layers are much worse (layer 24: 0.909).
- Truncated encoder: bit-identical to the full model at layers 1/6/9/12/18/23; layer 9 is 2.0× faster.
  The service's embed step dropped from ~280 ms to ~90 ms per clip on this desktop CPU.

### Verified manually (2026-10-14, desktop CPU, not a target device)
- Real XLS-R layer 12 run on Windows TTS voices (David = reference; Hazel/Zira = probes; 5 English words):
  the nearest word was correct 9/10 times (cat→dog was the miss). Embedding took ~280 ms per clip and DTW ~1 ms.
- Live chain `curl → backend /speech/assess → service /assess` took ~180–275 ms server time per call.
  **With the 0.30 fallback, "dog" was accepted as *cat* (0.216) and "fish" as *sun* (0.233).**
  Correct words scored 0.10–0.23. The placeholder threshold is far too lenient for XLS-R, and a single
  TTS reference gives no clean gap.

### UNTESTED / placeholders
- **The Flutter record screen with real speech.** On the Pixel 7 Pro emulator (2026-10-14) I verified:
  the permission prompt, recording start/stop, the auto-stop, and the upload through the Docker backend
  to the service. The silence error showed the gentle "couldn't hear" message. However, the emulator mic
  only delivered silence, so no spoken word has been scored from the app yet. To try it, run
  `adb emu avd hostmicon` and speak into the PC mic, or use a real phone.
- **What the layer sweep measures:** telling *different words* apart across children. Mispronunciations
  are much closer to the target than a different word, so the best layer for that finer task could
  differ. Re-check once labelled mispronunciations exist.
- **Word cuts are automatic** (MMS alignment) and have not been checked by ear yet. Tiny English words
  ("I", "a") often align to 20 ms slivers, so the sweep drops tokens < 0.12 s or align_score < 0.3.
- The sweep uses words cut from sentences (co-articulated), not isolated words as children will say them in the app.
- Only 4 dev children: the plateau differences (≈0.001 AUC) are within noise.
- `fallback_threshold: 0.30` is still wrong for XLS-R: with layer 9 it accepted "dog" as *cat* (0.249)
  and "fish" as *sun* (0.279). It needs Stage 3. `trim_top_db` is also a placeholder.
- The threshold in `tests/test_scoring.py` is computed from the scores it checks. It is a sanity demo,
  not accuracy evidence.
- Latency on a low-end Android path is unmeasured; `scripts/bench_latency.py` comes in Stage 6.
- `config/confusions.yaml`: TO VALIDATE WITH SPEECH-LANGUAGE EXPERT.
- `app/lib/l10n/app_si.arb`: Sinhala UI strings TO REVIEW BY A NATIVE SPEAKER.

## Open questions
- Team sign-off on adding shared gen-l10n (Stage 1) and the drift `AppDatabase` schema bump 2→3 for
  `pending_speech_recordings` (Stage 6).
- Card IDs for speech rewards (the catalog is opaque strings for now).
