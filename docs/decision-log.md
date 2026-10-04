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
| Nav restructured to **Home** + **Settings** (was 4 component tabs) | A single splash → Home flow reads better for a children's app; the four components are now reached via cards on Home rather than being top-level tabs, freeing a tab for Settings |
| Local `child_profiles` schema change applied as a destructive table recreate (`AppDatabase.schemaVersion` 1→2) | It's a local SQLite cache, not the backend's source of truth — losing a locally-cached profile just means the app re-creates a fresh default one on next splash, which is harmless at this stage |
| Splash screen logo is a placeholder (icon + wordmark) | No logo asset exists yet; `assets/branding/` + the pubspec entry are already wired up so dropping in a real `logo.png` later is a one-line swap in `splash_screen.dart` |

<!-- Add new entries below this line, newest at the bottom or top — pick one convention and stay consistent. -->
