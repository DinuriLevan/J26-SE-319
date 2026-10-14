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

<!-- Add new entries below this line, newest at the bottom or top — pick one convention and stay consistent. -->
