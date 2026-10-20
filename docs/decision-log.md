# Decision Log

A running log of structural/technical decisions for the AkuRin shared foundation. Add a new dated entry below whenever the team makes a decision that isn't obvious from the code.

## 2026-10-02 — Initial stack and scaffold decisions

| Decision | Rationale |
|---|---|
| Flutter + FastAPI + PostgreSQL + SQLite(drift) | Given stack, not re-litigated in this pass |
| Flutter state management: **Riverpod** | Compile-safe, scales to 4 people adding independent feature state without stepping on each other |
| On-device cache: **drift** | Type-safe queries + reactive streams (e.g. live "pending sync count") + built-in migrations, safer than hand-written SQL for a shared table 4 people write to |
| HTTP client: **dio** | Interceptors for base URL / logging / future retry logic in one place |
| Auth: **local-only, no backend auth** | Child profile (name/avatar/PIN) created locally; PIN only gates switching profiles on a shared device, not a real security boundary; backend trusts `child_id` from the client. Matches "no real auth complexity needed yet." |
| Backend dependency management: **requirements.txt** (not poetry/uv) | Lowest friction for a small student team, works simply in Docker |
| Backend DB driver: **sync SQLAlchemy + psycopg2-binary** | Simpler to reason about than async at this scale; team isn't backend-specialized |
| Flutter config: **`--dart-define` + `AppConfig` wrapper** (not flutter_dotenv) | Compile-time, zero extra dependency, no risk of committing a teammate's local IP into a bundled asset |
| `/ml` placeholders for all 4 components, including `math_memory/` | Keeps all four components symmetric even though math/memory may end up rule-based rather than ML-driven |
| `minSdkVersion`: **21** (Android 5.0) | Widest reach on older/cheaper devices, all chosen packages support it |
| Fonts: **Lexend** (Latin) + **Noto Sans Sinhala**, via `fontFamilyFallback` | Both free/open, bundled as assets (not fetched at runtime) to stay offline-first; avoids `google_fonts` package's runtime-fetch behavior |
| PIN storage: **salted hash**, not plaintext | Basic hygiene at negligible extra complexity, even though the PIN isn't a real security boundary |
| Alembic migrations auto-run (`alembic upgrade head`) on backend container startup | Convenience default so none of the 4 teammates forget to migrate; revisit if it ever causes a surprise schema change on restart |
| `ActivityResult` is one shared table (not one per component) | All four components write the same shape: `child_id`, `component_name`, `activity_id`, `result_payload` (JSON) — keeps the schema generic and avoids 4 near-duplicate tables |
| `LearnerProgress.progress_data` is a flexible JSON column | Each component's progress shape differs; a rigid schema would require a migration every time a component's progress format changes |

## 2026-10-02 — Single profile, no PIN; Home + Settings nav

| Decision | Rationale |
|---|---|
| Single local profile per install, no multi-profile picker | This app is used by one child per install; the "Who is learning today?" picker and profile switching added complexity nobody needs |
| PIN removed entirely | The PIN only ever existed to gate switching between profiles on a shared device — with no switching, it has no purpose |
| First launch auto-creates a default profile (no setup screen) | Zero-friction start; the child's name/avatar/language can be edited later from Settings instead of requiring input before the app is usable |
| Nav: bottom bar = the four components; sidebar drawer = Home, Profile, Settings | Children jump straight between components from the bottom bar; account-level pages live in a hamburger drawer. Home (greeting + cards) is the landing page with no bottom tab selected. Profile editing moved out of Settings into its own screen |
| Local `child_profiles` schema change applied as a destructive table recreate (`AppDatabase.schemaVersion` 1→2) | It's a local SQLite cache, not the backend's source of truth — losing a locally-cached profile just means the app re-creates a fresh default one on next splash, which is harmless at this stage |
| Splash screen logo is a placeholder (icon + wordmark) | No logo asset exists yet; `assets/branding/` + the pubspec entry are already wired up so dropping in a real `logo.png` later is a one-line swap in `splash_screen.dart` |

## 2026-10-14 — Speech & Pronunciation component setup (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| Speech app-layer endpoints (`/speech/assess` proxy, `/speech/progress/{child_id}`, `phoneme_progress` table) go in the **existing FastAPI backend** as an add-only router + Alembic migration | The project deck mentions Node.js, but the repo's backend is already FastAPI + SQLAlchemy + Alembic. Adding a second backend stack for one component would split the team's tooling |
| The speech model runs in a **separate Python (FastAPI) inference service** built from `ml/speech`, with its own docker-compose entry | Keeps torch/transformers (large, slow startup) out of the shared backend image; the backend proxies to it |
| Bilingual UI strings: **add shared Flutter gen-l10n** (`flutter_localizations` + ARB, `en` + `si`) | No l10n mechanism exists yet and all four components need Sinhala/English. It touches shared `pubspec.yaml`/`main.dart`, so it is added in the speech Stage 1 work and flagged for team agreement |
| Offline speech recordings get a **new add-only drift table `pending_speech_recordings`**, with an additive `AppDatabase` migration (schemaVersion 2→3) | The shared `pending_activity_results` queue holds finished JSON results, not unscored audio. Scored results still go through the shared queue |
| `ml/speech/data/` and all `*.wav` / `*.npy` under `ml/speech` are gitignored; development uses synthetic embeddings | Child audio and personal data must never be committed; children's recordings are collected only after ethics clearance |

## 2026-10-14 — Speech component Stage 1 (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| Speech word list lives in `ml/speech/config/words.csv` (committed), not in the gitignored `data/` | It's content, not personal data, and both the service and the app need the same ids |
| Resampling and silence trimming use scipy (`resample_poly`) and an RMS trim, not librosa | Fewer heavy dependencies at inference time and deterministic behaviour; librosa stays in requirements for notebooks |
| `data/embeddings/manifest.json` records which embedder built the reference bank; the service refuses to start on a mismatch | Prevents silently comparing XLS-R embeddings against embeddings from a different model, layer or the synthetic bank |
| A model-free `SpectralEmbedder` is used for tests and dev only | Tests run with no network and no 1.2 GB model download. It is never used for evaluation |
| `/speech/assess` is stateless in Stage 1; the app enqueues one shared `ActivityResult` per scored word through the existing offline queue | Reuses the documented CONTRIBUTING flow. `phoneme_progress` persistence and the "completed word" semantics arrive with the retry loop (Stage 5) |
| The app deletes each recording as soon as it has been scored | No child audio is kept on the device longer than needed |
| Main `AndroidManifest.xml` now declares `INTERNET` and `RECORD_AUDIO` | `INTERNET` was only in the debug/profile manifests, so release builds could not reach the backend. The mic permission is needed for speech |
| Backend `requirements.txt` gains `httpx` and `python-multipart` (add-only) | Needed by the speech proxy (outbound HTTP and multipart parsing). **Rebuild the backend image: `docker compose up --build`** |
| Note: the actual Android minSdk is **24**, not 21 | `build.gradle.kts` uses `flutter.minSdkVersion` (24 on Flutter 3.47), and `record` and `permission_handler` also require 24. The 2026-10-02 "minSdk 21" entry is out of date; team to confirm |

## 2026-10-15 — Speech component Stage 2: child corpus + layer sweep (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| Ethics approval confirmed by the component owner for the children's recordings in `ml/speech/data/grade*` (6 children, 360 sentence readings) | Required before any use of child audio. The data stays gitignored; speakers are anonymised as `g3_s1` and so on |
| Practice unit stays **single words** (not sentences) | Owner decision. Words are cut from the sentence recordings for development; a single-word recording list remains the target content |
| Split by **speaker**: test = `g3_s5`, `g4_s3`; dev = the other 4. `src/splits.py` raises if tuning code is given test rows | Spec rule: the test split is never used to choose layer, k, n or thresholds. Splitting by speaker keeps test children's voices unseen |
| Word boundaries come from **MMS forced alignment** (`torchaudio.pipelines.MMS_FA`) on uroman-romanised transcripts | Same model family as the spec's optional `ctc-forced-aligner` + uroman source, with no extra package. Boundaries are automatic and must be spot-checked (`scripts/export_spotcheck.py`) |
| **XLS-R layer = 9** | Dev-speaker sweep over 922 word tokens: best ROC-AUC (0.984). Layers 8–13 form a plateau (0.981–0.984); the last layers are much worse (layer 24: 0.909). Layer 9 is the best and the cheapest in that plateau. See `ml/speech/eval/results/layer_sweep_dev.md` |
| **Truncated encoder enabled** (keep `layer + 1` = 10 of 24 transformer layers) | `np.allclose` against the full model's `hidden_states[layer]` on 5 dev clips: max abs diff 0.0 at layers 1/6/9/12/18/23. A naive cut to `layer` layers differs by up to ~500 because XLS-R applies its final layer norm only to the last output. Layer 9 runs 2.0× faster |
| numba-JIT DTW (`src/dtw_fast.py`) for bulk evaluation | Identical costs and paths to the reference `scoring.dtw`, including ties (tested); ~160× faster. The live service still uses the reference implementation |

## 2026-10-15 — Speech component Stage 3: multi-reference bank + learned range (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| The service scores against **every reference** of a word (mean of k = 3 nearest) and accepts within a range **learned from the bank** (leave-one-out mean + 2·std). With fewer than 4 references it uses the fallback and reports `threshold_source: "fallback"` | Spec method (`src/threshold.py`). `scoring.mode: single` keeps the Stage 1 baseline available for comparison |
| `fallback_threshold` = **0.245** (was the 0.30 placeholder) | The single-reference threshold with the best balanced accuracy on **dev** trials (`ml/speech/eval/results/bank_study_dev.md`). The old 0.30 accepted 70% of near-miss words |
| **`loo_unit: speaker`** (approved by the owner 2026-10-15; the spec said "each reference against the others") | On dev, leaving out a reference's whole speaker fixes an over-strict range when a speaker has several takes (correct words accepted 77.8% → 89.9%; near-miss BA 0.855 → 0.861). It is identical to the spec when each speaker has one reference |
| **Demo words = frequent words from the child recordings** (අම්මා, මම, අපි, මට, cat, sky, she, play), each bank built from **dev children only** (6–14 refs from 4 children; `scripts/build_demo_bank.py`) | Owner decision, so the presentation shows the learned range working (every word gets `threshold_source: "bank"`). Test children stay out of the bank for the final evaluation. Children's voices as references are within the approved ethics scope. Adult references should be added later for variety |
| Bank files are named by **recording id** (`<speaker>_t<NN>`); the json's `speaker_id` identifies the speaker | Lets a speaker contribute several takes of a word, which speaker-level leave-one-out needs. Banks with one recording per speaker (`<speaker_id>.wav`) still work unchanged |
| The live service uses the numba DTW | Proven identical to `scoring.dtw` (`tests/test_dtw_fast.py`) and much faster for k-nearest over a bank |

## 2026-10-16 — Speech: adult references recorded in the app (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| Developer-only **reference recording mode** in the app (debug builds only) plus `POST /references` on the speech service (off unless `SPEECH_ALLOW_REFERENCE_UPLOAD=1`, **adults only**) | On a real phone, the owner's correct words scored 0.25–0.42 against a child-only bank (thresholds 0.18–0.28). Correct "cat" scored worse than a TTS "dog" (0.307), so no threshold could work. The bank must contain recordings made the way the app is used (single words, phone mic, varied speakers) |
| The owner consented to storing **adult** voice recordings locally in gitignored `ml/speech/data/`; children's voices are never stored by this mode | Data/ethics guard rails. Nothing is committed |

## 2026-10-16 — Speech component Stage 4: localisation + error mapping (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| Reference unit boundaries are **automatic now** (MMS forced alignment per unit, `scripts/align_units.py`, `units_source: "mms_fa"`), to be checked by ear later; hand-marked boundaries (`units_source: "manual"`) are never overwritten | Owner decision, so Stage 4 is not blocked on hand-marking about 100 clips |
| **English units are letter chunks** (`c|a|t`, `s|k|y`, `sh|e`, `p|l|ay`), not IPA | Owner decision: the aligner can handle them and children can read them. English alignment confidence is low (median 0.03–0.19 per chunk), so English localisation is less reliable |
| Localisation flags the worst unit, plus the second worst if its cost is ≥ 0.8 × the worst (placeholder). Error types are rule-based: duration vs expected (tempo-corrected) → omission/insertion; long vowel or geminate said short → distortion/omission; aspirated or prenasalised consonants → substitution; otherwise cost ≥ 0.5 → substitution, else distortion | Spec step 8. All ratios are placeholders, TO VALIDATE WITH SPEECH-LANGUAGE EXPERT |
| Error-type thresholds are **not tuned** on the spliced dev study | Spliced errors are all substitutions by construction, so tuning on them would just push every label to "substitution". Needs real labelled errors |

## 2026-10-16 — Speech component Stage 5: retry loop, remediation, progress, rewards (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| **Listen plays ADULT recordings only.** Units or words without an adult recording skip Listen (`GET /listen` → 404) | Owner decision: children's research recordings are never played to other children (ethics) |
| Retry loop lives in **both** `ml/speech/src/retry.py` (spec) and a Dart port (`app/.../logic/retry_loop.dart`); both run the shared scenarios in `ml/speech/tests/retry_cases.json` | Owner decision. The app drives the screens offline-capably, the spec's Python module stays the reference, and the shared JSON keeps them identical |
| Rewards: **milestone cards** `speech_words_5`, `speech_words_10`, … (every 5 different words mastered), via the shared `POST /rewards/{child_id}/unlock` | Owner decision. The mastered-word count comes from the app's local record of finished words (rows in the shared queue table, read-only) |
| **One `ActivityResult` per finished word** (mastered or fallback) instead of one per attempt | Matches the spec ("on each completed word"); attempt detail is kept in the payload's events |
| `phoneme_progress` (Alembic `0002`) is written by `POST /speech/assess-unit` for **single-unit** attempts; blends are practice steps, not units. `mastery` = EMA of pass/fail, alpha 0.3. If the child profile has not synced yet, the score is still returned and the row is skipped | Spec table; keeps the score path working before profile sync |
| Unit and blend references are cut **without padding** and are **pre-computed at service startup** (about 47 s for 30 spans) | Padding made a unit said alone look unlike its cut references. Computing on first use made the first attempt take 2.4 s (target < 2 s); after warm-up it is about 0.1 s |
| `just_audio` added to the shared `pubspec.yaml` (add-only); model audio is downloaded via the shared Dio client and played from a file | Spec package. Android's media player blocks plain-HTTP URLs, while the shared Dio client works |

## 2026-10-17 — Speech: choose the practice language first (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| The Speech tab opens by asking **"Which language do you want to practise?"** (සිංහල / English, each named in its own script). Only that language's words are shown, "next word" stays in that language, and a top-bar button switches language. The choice lasts while the app is open | Owner request. The practice language is separate from the UI language (the profile's `preferred_language`), so a child with a Sinhala UI can still practise English words |

## 2026-10-17 — Speech: 24 practice words in three difficulty levels (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| Word list grown from 8 to **24 (12 Sinhala, 12 English)**, all taken from words in the child recordings with ≥ 4 dev tokens from ≥ 2 children, so each has a reference bank (4–14 refs). Content words only (no "the", "in", ...) | Owner request: more words. Every word must have a bank, or it would only get the fallback threshold |
| **Three levels, rule-based** (`ml/speech/src/word_levels.py`, tested against `config/words.csv`). Sinhala: double consonant or conjunct → 3; else points = extra aksharas + long vowel + final hal (0/1/≥2 → 1/2/3). English: 2+ syllables → 3; else points = letter teams + extra onset consonants (0/1–2/≥3 → 1/2/3). TO VALIDATE WITH A TEACHER | Owner request: order easier → harder for Grades 2–3. Rules keep the levels transparent and reproducible instead of hand-picked |
| App shows words grouped as **Level 1 ★ / Level 2 ★★ / Level 3 ★★★**, easiest first; "next word" follows that order. No "hard" wording | Non-punitive presentation for children with dyslexia |
| `build_demo_bank.py` now replaces only `source: "child_corpus"` references | The previous rebuild deleted whole word folders, which would have erased adult app recordings |

## 2026-10-18 — Speech: 60 dyslexia-suitable words, readiness rule, span cache (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| Word list grown to **60 (30 Sinhala, 30 English)** from **two sources** (`source` column in `config/words.csv`): 16 more words from the child recordings (scorable now) and 20 **curated** words (need adult recordings) | Owner decision ("both", about 30 per language). The corpus alone has too few suitable words left |
| Selection criteria: concrete, everyday, picturable words a 7–9-year-old knows; no function words or inflected forms; English words decodable and regularly spelled (CVC, sh/ch/ck, common vowel teams), no irregular sight words. Levels stay rule-based (`src/word_levels.py`, tested). TO VALIDATE WITH A TEACHER / SLT | Suitability for children with dyslexia |
| A word is **ready** when its bank has **≥ 4 references** (same as `min_refs_for_bank_threshold`). Children see only ready words. Debug builds also show unready words, greyed with "needs recordings n/4", so developers can record them with the reference mode. `GET /speech/words` gains `n_refs` and `n_speakers` (additive) | Unscorable words must never reach children, while still being easy for developers to find and fill |
| **Span-embedding disk cache** (`data/embeddings/_spans/`, keyed by reference, span, cut times and padding; cleared by `build_embeddings.py`) | The unit/blend warm-up grew to 227 spans. The cache cuts start-up from 126 s (first run) to 6 s (later runs) |

## 2026-10-18 — Speech: child-friendly visual design (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| Speech screens get their own theme (`app/lib/features/speech/ui/speech_theme.dart`) layered over the shared theme; the shared theme, home shell and other components are unchanged | `app_theme.dart` asks components to layer their own styling within their feature folder |
| **Parrot buddy** guide, drawn in code (no image assets), with moods: idle, listening (recording), thinking (checking), happy (success), encourage (try again, with a heart) | Owner choice. Parrots "repeat words", which fits speech practice; the character keeps feedback warm and non-punitive |
| **Soft pastel** palette: cream background, navy text (no pure white or black), level colours mint/sky/lilac, coral mic. Lexend/Noto Sans Sinhala with wider spacing; target syllables shown as raised coloured tiles (no underlines or italics) | Owner choice; dyslexia-friendly style guidance |
| **Gentle motion + celebrations** (pulsing mic, sound waves, one-off confetti and stars, card flip). Every animation follows the system **reduce motion** setting | Owner choice; calm by default. Reduce motion also keeps widget tests deterministic |
| Practice and result screens scroll instead of overflowing on short screens (`FillOrScroll`) | Found by tests: the result screen overflowed by 112 px at 800×600 |

## 2026-10-18 — Speech: spoken instructions (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| The parrot **speaks every instruction and feedback line** (17 prompts per language, keyed by their l10n keys) | Children with dyslexia may not be able to read the bubble |
| Voice = **recorded adult prompts** bundled as app assets (`app/assets/speech/prompts/<en|si>/<key>.wav`, offline), with the device's **text-to-speech as fallback** when a prompt isn't recorded (`flutter_tts`, added add-only). If the device has no voice for the language, the line stays silent | Owner choice. A natural voice, offline-first, and usable before anything is recorded. Prompt audio is adult app content recorded with consent; child audio never goes in assets |
| **Auto-speak** once per new instruction, never while recording (the mic tap stops the voice); a **replay** button on the bubble; a **mute** toggle for auto-speech in the speech app bars | Owner choice |
| Spoken in the **app/UI language** (the profile's locale), not the practice language; switching language re-speaks | Owner choice: a Sinhala-speaking child practising English hears Sinhala instructions |
| The parrot speaks only while the Speech tab is selected | The home shell keeps every tab mounted (`IndexedStack`), so the parrot would otherwise talk over other screens |

## 2026-10-18 — Speech: a picture for each word (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| Every practice word has a picture: a **Twemoji SVG** (CC-BY 4.0, v15.1.0) bundled in `app/assets/speech/pictures/<word_id>.svg` (60 files, 243 KB) with `ATTRIBUTION.md`; the emoji is the `picture` column in `ml/speech/config/words.csv`, fetched by `scripts/fetch_word_pictures.py` from a version-pinned CDN URL | Owner choice. Pictures help children with dyslexia link the word to its meaning; bundling keeps them offline and identical on every phone (system emoji vary and are missing on old Android) |
| Shown on the word cards, the practice screen (large on the whole-word step, smaller while practising a sound) and the result screen; an attribution line sits under the speech word list | Owner choice; the smaller picture during practice keeps the highlighted syllables in focus |
| Abstract words get best-effort pictures (මම🙋, අපි🧑‍🤝‍🧑, මට🤲, වැඩ🧹, ලස්සන🌈, ran/runs🏃, fast🐆, she👩, play🤸, tasty😋), TO REVIEW WITH A TEACHER. Twemoji's family emoji (silhouette icons) were replaced by character pictures (අම්මා👩‍🍼) | Seen on the emulator: Twemoji draws family sequences as abstract blue pictograms, which don't suit children |
| `flutter_svg` added (add-only, pure Dart) | Sharp at any size; the 72 px PNGs would blur at the practice-screen size |

## 2026-10-18 — Speech: hear before saying (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| A **"Hear it"** button under the syllable tiles on every practice step except Listen (which already plays the model); it plays the whole word, or the target span on Say/Blend steps. Disabled while recording or checking | Children can hear the model before they try |
| **Tap only**: nothing plays automatically | Owner choice: the first attempt stays a genuine reading attempt |
| Model voice = the **adult reference recording** (`GET /speech/listen`, adults only) when one exists; otherwise the device's **text-to-speech** in the word's (practice) language. A network error counts as "no recording". Uses the parrot's audio channel, so a mic tap stops it | Owner choice; works before adult recordings exist |
| **Tap a syllable tile** to hear that sound (speaker badge on tappable tiles). **English tiles use adult recordings only** and are tappable only where one exists; Sinhala aksharas may fall back to TTS | TTS reads a lone English letter by its name ("c" → "see"), which would teach the wrong sound. Sinhala aksharas are spoken syllables |

## 2026-10-20 — Speech: Sinhala field recordings and the Listen voice (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| One adult and two new children recorded all 30 Sinhala words. They were imported as references by `ml/speech/scripts/import_recordings.py` (`source: field_recording`, speakers `fr_a1`, `fr_c1`, `fr_c2`); the audio stays in git-ignored `ml/speech/data/` | Ethics approval confirmed; isolated words match how children say words in the app, unlike words cut from sentences |
| Both children are **dev** speakers in the bank; the test speakers g3_s5 and g4_s3 are untouched, and the import refuses test speaker ids | Owner choice; more speakers widen the learned ranges and make 26/30 Sinhala words ready |
| File-name spellings පුසා, පාසල and මල්ලී map to the app words පූසා, පාසල් and මල්ලි | Owner-confirmed file-name typos |
| The same three people recorded all 30 **English** words (90 clips). They use the same language-neutral ids in both languages (the first Sinhala import used `si_*` and was re-imported). File-name typos hart→hat and boy9→boy were owner-confirmed | Owner: same people. One id per person keeps leave-one-speaker-out ranges honest across takes |
| The **adult `fr_a1` is the Listen voice** for both languages (`listen.preferred_speaker` in `settings.yaml`), so the Listen step, "Hear it" and syllable/letter taps all use it; for English it replaces adult_01 for Listen only. Any other adult is the fallback; children's clips are never played | Owner request; a real voice instead of text-to-speech |

## 2026-10-20 — Speech: accuracy, one shared pass mark per language (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| Whole-word decisions use **one pass mark per language** (`scoring.threshold_mode: shared`, `shared_threshold: {si: 0.2713, en: 0.2700}`) instead of a range learned per word (mean + 2 sd). The per-word method stays available (`threshold_mode: per_word`) | Owner choice. Dev study (`ml/speech/eval/results/threshold_study_dev.md`): per-word ranges learned from 3–17 recordings were noisy. For single-word children, correct words rejected went 19.7% → 13.1% (si) and 28.3% → 10.0% (en); wrong words accepted went 10.9% → 7.5% (si) and 10.8% → 16.3% (en, nested estimate from one child; about 8% when chosen on both) |
| The pass mark is the score below which **90% of correct attempts** fall (at most 10% false "try again"), chosen on **dev children recorded saying single words** (fr_c1, fr_c2) | Owner priority: fewer false "try again" (encouraging, non-punitive). The app hears single words; words cut from sentences score closer together and would set too strict a mark. Test children were not used |
| Unit/blend pass marks in the remediation loop are unchanged (still learned per span) | Not studied yet |
| A **mispronunciation test set** is prepared: `ml/speech/eval/mispronunciations.csv` lists one deliberate mispronunciation per word (categories TO VALIDATE WITH A SPEECH-LANGUAGE EXPERT, Sinhala forms TO REVIEW BY A NATIVE SPEAKER); `eval/mispronunciation_study_dev.py` scores the recordings with the recorder left out of the bank | Owner choice. "Wrong words" are far easier to reject than real mispronunciations, so accuracy on these is still unmeasured |

## 2026-10-20 — Speech: sound steps are practice, not tests (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| "Say the sound" and "say them together" steps are **not scored**: the child says the sound, the parrot says "Good practice! Let's keep going." and the loop moves on. The recording is deleted, never uploaded. Only the whole word is scored. Switch: `scoreSoundSteps` in `speech_word_screen.dart` | Owner choice. On a real phone, single sounds passed 1 time in 41 tries (scores about 0.39–0.42 vs pass marks about 0.25), so a missed word became 6–9 rounds of "try again". Unit references are cut out of whole words (a "t" in "cat" is a 40 ms stop), while a child says a sound alone as "tuh" |
| Flagged sounds are still put on the "practise later" list | Practising a sound once does not show it is mastered |
| The retry loop (Python `src/retry.py` and Dart `retry_loop.dart`) gains `on_practised` / `onPractised`, with 2 new shared scenarios in `retry_cases.json` | The two ports stay identical |
| To score sounds again, record **sounds said alone** by adults (e.g. "tuh", "kuh", "ම") as unit references and tune unit pass marks on them | Long-term fix |

## 2026-10-20 — Parent dashboard (shared shell) with the Speech section (Fernando B.P.L)

| Decision | Rationale |
|---|---|
| A **Parent dashboard** item in the main menu (`shared/widgets/app_drawer.dart`, one added `ListTile`) opens `features/parent_dashboard/`: one tab per component (Math & Memory, Spelling & Phonics, Handwriting, Speech & Pronunciation) | Owner request. Add-only in shared code. Each team owns its tab: replace its `ParentSectionPlaceholder` in `parent_sections.dart` with a widget from its own feature folder |
| A **grown-up check** before it opens: a times-table question (6-9 x 6-9) | Owner choice; keeps Grade 2-3 children out. A speed bump, not security |
| The Speech tab (`features/speech/parent/`) shows words mastered and still practising, sounds to practise (with the adult voice), recent activity (14 days), improvement over time (weekly first-try success and average tries) and tips for grown-ups | Owner choice of content. Built from the finished-word results already stored **on this device** (shared `pending_activity_results`, no schema change), so it works offline; it only covers practice on this device |
| No raw scores and no diagnosis wording; a footnote says "A practice aid, not a clinical assessment" | Project guard rail (practice aid, not a clinical tool) |
| Tips and the Sinhala text are TO REVIEW BY A TEACHER / NATIVE SPEAKER | Not yet reviewed |

<!-- Add new entries below this line, newest at the bottom or top — pick one convention and stay consistent. -->
