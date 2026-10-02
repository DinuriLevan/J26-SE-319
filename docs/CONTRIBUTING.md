# Contributing your component

This repo is a shared foundation. Each of the four feature components (Math & Memory, Spelling & Phonics, Handwriting, Speech & Pronunciation) plugs into it the same way. This guide is concrete, not conceptual — follow it in order.

## 1. Add your screen in `/app`

Your stub screen already exists at `app/lib/features/<your_component>/`:

- Math & Memory → `app/lib/features/math_memory/math_memory_stub_screen.dart`
- Spelling & Phonics → `app/lib/features/spelling/spelling_stub_screen.dart`
- Handwriting → `app/lib/features/handwriting/handwriting_stub_screen.dart`
- Speech & Pronunciation → `app/lib/features/speech/speech_stub_screen.dart`

Build your feature inside that folder (add widgets, providers, local logic as subfolders/files next to the stub screen). Don't rename the top-level file or move it out of `features/<your_component>/` — `home_screen.dart` references it directly.

Your screen is already wired up as a card on the Home tab (`app/lib/features/home/home_screen.dart`) — tapping it pushes your stub screen. The app's bottom nav itself only has two tabs, Home and Settings (`app/lib/features/home_shell/home_shell_screen.dart`); you shouldn't need to touch that file unless you're changing your card's title or icon on Home.

## 2. Submit activity results

Whenever a child completes an activity in your component, write a row to the local offline queue (not directly to the network — this keeps things working offline):

```dart
await ref.read(appDatabaseProvider).pendingActivityResultDao.enqueue(
  childId: currentChildId,
  componentName: 'math_memory', // or 'spelling' / 'handwriting' / 'speech'
  activityId: 'your-activity-identifier',
  resultPayload: jsonEncode({/* whatever shape makes sense for your activity */}),
);
```

The shared `sync_service.dart` will flush this to the backend's `POST /activity-results` automatically when connectivity allows. You do not need to call the API directly.

## 3. Read/write learner progress

To read your component's current progress for the active child:

```
GET /learner-progress/{child_id}?component_name=math_memory
```

To update it (e.g. after recalculating a skill score):

```
PUT /learner-progress/{child_id}/math_memory
Body: { "progress_data": { ...whatever shape your component needs... } }
```

`progress_data` is a free-form JSON object — design whatever shape fits your component. See [api-contract.md](api-contract.md) for the full endpoint list.

## 4. Where your model code goes

Put training scripts, notebooks, saved weights, and model-specific requirements under your folder in `/ml`:

- `ml/handwriting/`
- `ml/speech/`
- `ml/spelling/`
- `ml/math_memory/`

These folders are empty placeholders — structure them however suits your model. They are not imported by the Flutter app or the FastAPI backend directly; if your model needs to run as part of the backend (e.g. an inference endpoint), add a new router under `backend/app/routers/` and discuss the shared-table schema implications with the team first, since `ActivityResult` and `LearnerProgress` are intentionally generic.

## 5. Rewards / card album

If your component unlocks cards as a reward:

```
POST /rewards/{child_id}/unlock
Body: { "card_id": "your-card-identifier" }
```

The card catalog itself isn't modeled in the database yet — card IDs are just opaque strings for now. Coordinate with the team before introducing a formal card catalog table.

## Local dev setup

See the root [README.md](../README.md) for cloning, running `docker compose up`, and running the Flutter app against it.
