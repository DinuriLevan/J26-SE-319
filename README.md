# AkuRin (J26-SE-319)

AI-Driven Learning Platform for Literacy Development in Children with Dyslexia — a Sinhala-English bilingual app for children aged 7-9, offline-first, targeting low-end Android devices.

This repo is the **shared foundation** four team members build their own component on top of: Math & Memory, Spelling & Phonics, Handwriting, and Speech & Pronunciation. See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for how to plug your component in, and [docs/decision-log.md](docs/decision-log.md) for why things are built the way they are.

## Repo layout

```
/app        Flutter mobile app (shared shell + your feature screen)
/backend    FastAPI service (shared API + database)
/ml         Placeholder folders for each component's model code
/docs       API contract, architecture decisions, contribution guide
```

## 1. Backend — Docker Compose

```sh
cp .env.example .env
docker compose up --build
```

This starts PostgreSQL and the FastAPI backend together. On first boot the backend container runs `alembic upgrade head` automatically, then starts `uvicorn` with hot reload.

Once running:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Raw OpenAPI spec: http://localhost:8000/openapi.json
- Health check: http://localhost:8000/health

Postgres is exposed on host port **5433** (not 5432) to avoid clashing with any other local Postgres you might be running; the backend itself talks to it over the Docker network as `db:5432`, unaffected by that.

## 2. Flutter app

> **One-time setup note:** this scaffold was authored without the Flutter SDK installed, so the native `android/` (and `ios/`) platform folders aren't included yet. The **first** person setting this up should run, from inside `/app`:
> ```sh
> flutter create . --org com.akurin --project-name akurin
> ```
> This generates the platform folders around the existing `lib/`, `pubspec.yaml`, and `assets/` without overwriting them (Flutter skips files that already exist). After that, open `android/app/build.gradle` and set `minSdkVersion = 21` (see decision-log.md), then commit the generated `android/` folder so the rest of the team doesn't need to repeat this step.

Then, for everyone:

```sh
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates drift's .g.dart files
```

Run against the backend:

```sh
# Android emulator (loopback to host machine):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Physical device on the same network (replace with your machine's LAN IP):
flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000
```

The app opens to a profile selection screen (name + avatar + PIN, stored locally — no backend auth). After picking or creating a profile, you land on the home shell with four tabs, one per component.

## 3. Where things live

- Shared API contract: [docs/api-contract.md](docs/api-contract.md) (the live OpenAPI spec is the source of truth)
- How to add your component: [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)
- Stack/structural decisions and why: [docs/decision-log.md](docs/decision-log.md)
- Recommended VS Code extensions: `.vscode/extensions.json` (VS Code will prompt you to install them)
