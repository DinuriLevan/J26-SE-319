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

<!-- Add new entries below this line, newest at the bottom or top — pick one convention and stay consistent. -->

## 2026-10-18 — Math & Memory: adaptive games and local progress

| Decision | Rationale |
|---|---|
| New local drift table `local_learner_progress` (`childId`, `progressKey`, JSON `progressData`), `AppDatabase.schemaVersion` 2→3, additive migration | Games must adapt offline and remember attempt counts / difficulty across restarts. The sync queue isn't a progress store. Generic and keyed per feature (Math & Memory uses one key per game), mirroring the backend's free-form `learner_progress` JSON; any component can reuse it |
| `AppDatabase` takes an optional `QueryExecutor` | Lets tests use `NativeDatabase.memory()`; production behaviour unchanged |
| First completed attempt per game = ungraded baseline; later attempts scored and adaptive; abandoned attempts never change progress | See [math-memory-adaptive-engine.md](math-memory-adaptive-engine.md) |
| Rules-based adaptive engine (`rules_v1`), not ML | Deterministic, testable, explainable foundation; every attempt's payload records the data a future model would need |
| Results use the existing `pending_activity_results` queue with `component_name: "math_memory"`, `activity_id` = game id | No backend or API change needed; `result_payload` is free-form JSON |
| Local progress is not yet pushed to `PUT /learner-progress` | Kept out of scope to avoid a second sync path; progress can be rebuilt from queued payloads (`adaptation.state_after`) |

## 2026-10-18 — Math & Memory: trained next-attempt models

| Decision | Rationale |
|---|---|
| Next-attempt configuration chosen by a trained scikit-learn model (Number Quest: decision tree; Memory Match: random forest); in-attempt rules kept | The model replaces only the between-attempt choice the rules made; hints/reinforcement inside an attempt already worked and are unchanged |
| Models exported to JSON and evaluated by a small Dart tree evaluator (`TreeEnsembleModel`), bundled as app assets | Offline on Android with **no new Flutter dependency** (no TFLite/ONNX runtime); trees are tiny; Python/Dart parity is tested on 600 cases |
| Training data is synthetic (expert-authored learner simulator), clearly labelled as such in artifacts, reports and payloads | No real learner data exists yet; every queued attempt now records the features and prediction needed to train on real data later |
| Training runs in `python:3.12-slim` via Docker with pinned requirements | Reproducible without a local Python install (Docker is already used for the backend) |
| Rules engine is the fallback; payload records `next_attempt.source` = `model` / `fallback` | Games never break if an artifact is missing or incompatible, and every decision is traceable |
| Memory Match predictions use an 11-rung (pictures, seconds) ladder where neighbours differ in one factor | One model output, bounded steps, never changes both factors at once |
