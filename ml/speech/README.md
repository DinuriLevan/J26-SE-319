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

1. Build the bank: `python scripts/build_demo_bank.py` (child references from the corpus), and/or add
   your own clips at `data/reference/<word_id>/<recording_id>.wav`, each with a sibling `<recording_id>.json`:
   `{"speaker_id": "spk_adult_01", "age_group": "adult", "accent": "standard", "units": []}`
   (`units` can stay empty until Stage 4). Stage 1 uses the first adult reference by `speaker_id`,
   or the one set in `baseline.reference_speaker` in `config/settings.yaml`.
2. `python scripts/build_embeddings.py`. The first run downloads XLS-R (~1.2 GB) to the HuggingFace cache.
3. `uvicorn src.service:app --port 8001`. This loads the model once and runs a warm-up inference.
   Interactive docs are at http://localhost:8001/docs.
4. Backend: `docker compose up --build` (the rebuild installs `httpx`). Inside Docker, the backend reaches
   the service at `http://host.docker.internal:8001`; override this with `SPEECH_SERVICE_URL`.
5. App: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`, then open the Speech tab.

**Adding adult references from the phone (developer tool):** start the service with
`SPEECH_ALLOW_REFERENCE_UPLOAD=1`. In a debug build, open a word and tap the "library" icon at the top
right, enter a speaker id (e.g. `adult_01`, a different id per person), and record the word. A banner
shows that recordings are being saved as references, not scored. Each save relearns that word's
threshold. Adults only: the service rejects any other `age_group`. Test with a *different* person than
the one who recorded the references, or you are matching your own voice.

**Spoken instructions (the parrot's voice):** the app speaks each instruction from a recorded adult
voice, or from the phone's text-to-speech until one is recorded. To record:
1. `python scripts/prepare_prompts.py --script` writes `data/prompts/RECORDING_SCRIPT.md`: 17 lines
   × English/Sinhala, taken from the app's text so the voice matches the bubble.
2. An adult (with consent) reads each line warmly and slowly. Save as `<folder>/en/<key>.wav` and
   `<folder>/si/<key>.wav` (wav/ogg/flac).
3. `python scripts/prepare_prompts.py --in <folder>` cleans the recordings (mono 22.05 kHz, trimmed,
   loudness-normalised) into `app/assets/speech/prompts/`, and reports missing keys. Rebuild the app.

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
| 3 Bank + learned range | Done: multi-reference scoring, leave-one-out range, fallback; dev study vs single reference |
| 4 Localisation + errors | Done: automatic unit boundaries, unit flagging, rule-based error types; spliced-error dev study |
| 5 Retry loop + remediation | Done: retry.py and its Dart port (shared scenarios), unit/blend scoring, adult Listen audio, practice screens, phoneme_progress, milestone cards. **Not yet run end-to-end by a person on a phone** |
| 6–7 | Not started |

## Child corpus (Stage 2)

Ethics approval confirmed 2026-10-15. Recordings live in `data/grade*` (gitignored).

```sh
python scripts/build_child_corpus.py   # -> data/corpus/utterances.csv (anonymous speaker ids, dev/test split by speaker)
python scripts/align_words.py          # -> data/corpus/words.csv (MMS forced-aligned word boundaries)
python scripts/export_spotcheck.py     # -> data/corpus/spotcheck/*.wav + spotcheck.csv to check cuts by ear
python scripts/layer_sweep.py          # -> eval/results/layer_sweep_dev.{csv,md,png}  (dev speakers only)
python scripts/verify_truncation.py    # -> eval/results/truncation_check.json
python scripts/embed_corpus_words.py   # -> data/corpus/emb/<model>_l<layer>/*.npy (service embedder)
python eval/bank_study_dev.py [--loo token|speaker]   # -> eval/results/bank_study_dev[_loso].{csv,md}
python scripts/build_demo_bank.py      # -> data/reference/<word_id>/<speaker>_tNN.{wav,json} (dev children only)
python scripts/build_embeddings.py     # -> data/embeddings/ for the bank
python scripts/align_units.py [--spotcheck 30]       # unit boundaries into every reference json
python eval/localisation_study_dev.py [--children-only]  # -> eval/results/localisation_study_dev*.md
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

- `tests/test_threshold.py`: fallback below 4 refs; LOO maths and k capping; numba and reference DTW
  give the same range; **the learned range accepts the correct word and the accent variant and rejects
  the wrong sound** (3+3 and 3+2 synthetic banks); speaker-level LOO ignores same-speaker takes.
- `tests/test_service.py`: both modes. `single` = first adult + fallback; `bank` = fallback below 4 refs,
  learned range at 5 refs accepts correct and variant and rejects the wrong middle unit.

### Stage 3 dev study (2026-10-15, dev children only; words cut from sentences)
Balanced accuracy (BA). "Bank regime" = trials whose bank has ≥ 4 references (17% of queries).
"Near-miss" wrong words have the closest romanised spelling, a rough stand-in for mispronunciations.

| System (bank regime) | accept correct | BA random wrong | BA near-miss |
|---|---|---|---|
| Single reference + old 0.30 | 0.987 | 0.931 | 0.642 |
| Single reference + dev-best 0.245 (in-sample, optimistic) | 0.943 | 0.964 | 0.858 |
| Bank + learned range, LOO by token (spec) | 0.778 | 0.887 | 0.855 |
| Bank + learned range, LOO by speaker | 0.899 | 0.938 | 0.861 |

Honest reading: the bank needs no tuned threshold yet matches an in-sample-tuned single reference on
near-misses. It does not clearly beat it, and it is behind on random wrong words. These numbers are from
4 children, a proxy task (different words, not real mispronunciations), and child-only references.

- `tests/test_localise.py`: unit frames tile the reference (min frames, ordering); error rules
  (omission, insertion, cost-based, geminate and long vowel said short, aspirated stop); on synthetic
  prototypes the wrong middle or first unit is flagged, and a skipped unit is flagged as omission.
- `tests/test_service.py`: a rejected attempt returns segments with the wrong middle unit flagged;
  an accepted attempt returns none.

### Practice words (2026-10-18)
60 words (`config/words.csv`), easiest first; levels from `src/word_levels.py` (TO VALIDATE WITH A
TEACHER). Criteria: concrete, everyday, picturable; no function words or inflected forms; English words
decodable and regularly spelled. *Italic* = curated, which becomes **ready** (shown to children) once it
has ≥ 4 references (counts as of 2026-10-20 in brackets). Debug builds list unready words greyed, with
"needs recordings n/4".

| Level | Sinhala | English |
|---|---|---|
| 1 | මම, අපි, මට, කිරි, වැඩ, ඇය, *ගස (5)*, *අත (3)*, *ඇස (3)*, *ඉර (5)*, *කට (3)* | cat, hat, rat, ran, fast, runs, *dog (3)*, *sun (6)*, *bus (3)* |
| 2 | බත්, මල්, පාට, ගෙදර, පොත්, *වතුර (4)*, *හාවා (3)*, *පූසා (5)* | she, sky, play, book, boy, toy, ball, fly, rice, birds, *fish (5)*, *ship (3)*, *frog (5)* |
| 3 | අම්මා, අක්කා, තාත්තා, පාසල්, මල්ලි, ලස්සන, සෙල්ලම්, පාඩම්, කියවයි, *බල්ලා (5)*, *කෙසෙල් (5)* | school, apple, garden, tasty, *rabbit (3)*, *window (3)*, *sister (3)*, *pencil (5)* |

- **Pictures:** each word has a Twemoji picture (CC-BY 4.0) from the `picture` column, fetched with
  `python scripts/fetch_word_pictures.py` (only missing files; `--force` refreshes all) into
  `app/assets/speech/pictures/`. Abstract words have best-effort pictures, TO REVIEW WITH A TEACHER.
- **Hear before saying** (app): a "Hear it" button and tappable syllable tiles play the adult
  recording from `/speech/listen`, or the device's text-to-speech when there is none. English letter
  tiles never use TTS (letter names), so they are tappable only with adult recordings. Tap only.
- Ready now: 26 Sinhala (අත, ඇස, කට, හාවා need one more recording each) and 24 English (dog, bus,
  ship, rabbit, window, sister need one more each). To make a curated word ready, record it with the reference mode from 4
  minus its count different adults (one take each).
- **Risk:** banks from only 2 children have narrow ranges and may reject correct new speakers: hat,
  toy (std 0.002, threshold 0.148), ඇය, සෙල්ලම්, කියවයි, and others. Adult recordings widen them.
- Span-embedding cache: first start-up about 126 s (227 spans), later start-ups about 6 s.

### Field recordings (2026-10-20)
One adult (`fr_a1`) and two new children (`fr_c1`, `fr_c2`), the same three people in both
languages, recorded every practice word as a single word: 91 Sinhala clips (child 1 said වතුර
twice) and 90 English clips, 181 references in total. All three are **dev** speakers; the test speakers are untouched.
The files are git-ignored under `data/new voice/`. They are imported with:

```
python scripts/import_recordings.py --src "data/new voice/adult sinhala"     --speaker fr_a1 --age-group adult --language si
python scripts/import_recordings.py --src "data/new voice/child  1 sinhala" --speaker fr_c1 --age-group child --language si
python scripts/import_recordings.py --src "data/new voice/child 2 sinhala"  --speaker fr_c2 --age-group child --language si
python scripts/import_recordings.py --src "data/new voice/adult english"     --speaker fr_a1 --age-group adult --language en
python scripts/import_recordings.py --src "data/new voice/child 1 english"  --speaker fr_c1 --age-group child --language en
python scripts/import_recordings.py --src "data/new voice/child 2 english"  --speaker fr_c2 --age-group child --language en
python scripts/build_embeddings.py && python scripts/align_units.py --spotcheck 20
```

- **File-name typos** (owner-confirmed):
  - පුසා, පාසල and මල්ලී are පූසා, පාසල් and මල්ලි;
  - hart is hat;
  - a stray digit after a word (boy9, play9, apple9) is dropped.
- **Re-imports** replace only that speaker's field recordings in the language being imported.
  `--replace-speaker` removes a renamed id; the first Sinhala import used `si_*` ids.
- **Listen voice:** `listen.preferred_speaker: {si: fr_a1, en: fr_a1}`, so the Listen step, "Hear it" and
  syllable or letter taps play this adult for all 60 words. For Listen this replaces adult_01 on
  cat, sky, she and play; adult_01 stays in the bank for scoring. Children's clips are never played.
  - Every English word now has adult letter audio, so all English tiles are tappable.
  - Verified with curl: the word and unit 1 of cat, hat, window, sky and මම all return `fr_a1_r01`.
  - Verified on the emulator (Sinhala only, before the English import): මම "Hear it" and a tile tap
    each made a `/listen` request that returned 200.
- **Ranges:** 26/30 Sinhala and 24/30 English words have learned ranges. The rest have 3 refs and use
  the fallback.
- **Dev-only sanity check** (reported, not used to tune anything): each new child was scored
  against the bank without them.
  - Sinhala: fr_c1 24/31, fr_c2 25/30.
  - English: fr_c1 23/30, fr_c2 20/30.
- **Short letter cuts:** 19 of the adult's 174 unit cuts are under 60 ms, mostly word-initial
  consonants (p, b, f, r) that are naturally short. Suspicious ones are "n" in garden (31 ms) and
  "t" in fast (21 ms); these may sound clipped.
- **UNTESTED:**
  - how the adult clips and the cut units sound (spot-check clips are in
    `data/corpus/unit_spotcheck/`);
  - English letter taps on the emulator.

### Stage 5 (2026-10-16)
- Tested: `tests/test_retry.py` and the Dart `retry_loop_test.dart` both pass the 7 shared scenarios
  (happy path, one retry, exhaustion, two flagged units, no listen audio, single-unit word, blend
  exhaustion). `tests/test_units_api.py`: the right isolated sound is accepted and a wrong one rejected,
  blends work, spans are validated, and Listen serves adults only (404 for child-only words). Backend:
  `test_speech_progress.py` (attempts, successes, mastery EMA, blends not recorded, unsynced child,
  ordering). Flutter: API, result screen (en/si, never "wrong"), milestone rule, completed-word payload.
- Verified live through the Docker backend: `/speech/words`, `/speech/listen` (adult clip; 404 for
  අම්මා), `/speech/assess-unit` about 0.1 s after warm-up, and the Alembic `0002` migration applied.
- **UNTESTED:** the full practice loop on a phone with a real child-like voice; unit scoring on
  sounds actually *said alone* (references are cut from words, so expect a mismatch); English blends
  are weak (a "ca" blend accepted a lone "a" because "c" is a ~40 ms auto-aligned chunk); milestone
  unlock when offline (Stage 6).

### Stage 4 dev study (2026-10-16, spliced errors in dev children's references, LOSO banks)
One unit of a dev child's reference is replaced by a unit from a different word; we check which unit is flagged.

| Bank | detected | right unit top flag | right unit among flags | clean accepted |
|---|---|---|---|---|
| children + adult_01 app recordings | 0.578 | 0.740 | 0.904 | 0.936 |
| children only | 0.756 | 0.743 | 0.934 | 0.923 |

- Localisation meets the ≥ 70% target on this proxy (Sinhala 0.84 top-1; English 0.58–0.65, which
  matches its weak letter alignment).
- **One adult's many takes loosen a word's threshold**: sky caught 0/30 spliced errors with adult_01's
  7 takes in the bank vs 20/30 without them. More adult speakers (so adult takes have peers) should fix
  this. Otherwise consider a robust range (median/MAD), which would need approval.
- **Error types are not calibrated**: spliced units are substitutions, but 88% were labelled distortion
  (`substitution_cost` 0.5 is too high). Needs real labelled errors.

### Verified manually (2026-10-14, desktop CPU, not a target device)
- Real XLS-R layer 12 run on Windows TTS voices (David = reference; Hazel/Zira = probes; 5 English words):
  the nearest word was correct 9/10 times (cat→dog was the miss). Embedding took ~280 ms per clip and DTW ~1 ms.
- Live chain `curl → backend /speech/assess → service /assess` took ~180–275 ms server time per call.
  **With the 0.30 fallback, "dog" was accepted as *cat* (0.216) and "fish" as *sun* (0.233).**
  Correct words scored 0.10–0.23. The placeholder threshold is far too lenient for XLS-R, and a single
  TTS reference gives no clean gap.

### Found on a real phone (2026-10-16, Samsung SM-A176B)
- Against the child-only demo bank, the owner's correct words all scored above threshold (cat 0.36–0.42 vs
  0.282; sky 0.39–0.41 vs 0.210; she 0.253 vs 0.183; මට 0.412 vs 0.194), so every attempt got "Nice try".
  Correct "cat" scored worse than a TTS "dog" (0.307), so this is a reference-coverage problem
  (child voices cut from read sentences, different device), not a threshold problem.
  Fix in progress: adult phone references via the developer recording mode.

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
- `fallback_threshold` is now 0.245 (dev-chosen). `n_std = 2` and `k = 3` are still the spec defaults and
  have not been tuned. `trim_top_db` is a placeholder.
- Demo bank (`scripts/build_demo_bank.py`): 8 words with 6–14 child references each, from dev children
  only. Learned thresholds are 0.174–0.282. Smoke test with computer voices as *cat*: Zira and David were
  accepted, British Hazel just missed (0.286 vs 0.282), and dog, book and fish were all rejected. The bank
  is **child-only** and has no adult references yet.
- The threshold in `tests/test_scoring.py` is computed from the scores it checks. It is a sanity demo,
  not accuracy evidence.
- Latency on a low-end Android path is unmeasured; `scripts/bench_latency.py` comes in Stage 6.
- `config/confusions.yaml`: TO VALIDATE WITH SPEECH-LANGUAGE EXPERT.
- **Hear before saying, on the emulator (2026-10-18):** cat fetched adult audio for the word and the
  "a" tile (`/speech/listen` 200); මම made no listen request (TTS path); hat's tiles have no badges and
  ignore taps. Not checked: how it sounds (I could not hear the emulator), and that Hear it is
  disabled while recording (covered only by the screen's idle check).
- `app/lib/l10n/app_si.arb`: Sinhala UI strings TO REVIEW BY A NATIVE SPEAKER.

## Open questions
- Team sign-off on adding shared gen-l10n (Stage 1) and the drift `AppDatabase` schema bump 2→3 for
  `pending_speech_recordings` (Stage 6).
- Card IDs for speech rewards (the catalog is opaque strings for now).
