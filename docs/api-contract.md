# API Contract

This file is a plain-language summary. The **live OpenAPI/Swagger spec is the source of truth** going forward:

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`
- Raw OpenAPI JSON: `http://localhost:8000/openapi.json`

If this file and the live spec ever disagree, the live spec wins — update this file to match.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/child-profiles` | Create or sync a child profile (id is client-generated UUID, from local drift storage) |
| `GET` | `/child-profiles/{child_id}` | Fetch a single child profile |
| `POST` | `/activity-results` | Submit one activity result, tagged by `component_name` (e.g. `"handwriting"`, `"speech"`, `"spelling"`, `"math_memory"`). This is the one shared table all four components write to. |
| `GET` | `/activity-results?child_id=&component_name=` | List activity results, with optional filters |
| `GET` | `/learner-progress/{child_id}` | Get all progress rows for a child, across all components |
| `GET` | `/learner-progress/{child_id}?component_name=` | Get progress for one component |
| `PUT` | `/learner-progress/{child_id}/{component_name}` | Upsert (create or replace) a component's progress blob — `progress_data` is a free-form JSON object, each component defines its own shape |
| `GET` | `/rewards/{child_id}` | Get a child's unlocked reward cards |
| `POST` | `/rewards/{child_id}/unlock` | Unlock a reward card for a child |
| `POST` | `/speech/assess` | Speech component: score one spoken word (multipart; proxied to the speech inference service). See below |

## Auth

There is no authentication on these endpoints. `child_id` is trusted as sent by the client. This is intentional for the MVP — see [decision-log.md](decision-log.md) for the reasoning.

## `component_name` values

Use one of: `"handwriting"`, `"speech"`, `"spelling"`, `"math_memory"`. This is a free-text field, not an enum, so a new component can be added without a migration — but stick to these four names for consistency.

## Speech component (`/speech/*`)

`POST /speech/assess` takes `multipart/form-data` with these fields:

| Field | Type | Notes |
|---|---|---|
| `audio` | file | WAV, at most ~6 s and 2 MB. Any sample rate or channel count; the server converts to 16 kHz mono |
| `word_id` | string | Must exist in `ml/speech/config/words.csv`, e.g. `w_001` |
| `language` | `si` \| `en` | Must match the word's language |
| `child_id` | UUID | Not forwarded to the model service |

The response is `200` with the following body. Field names are fixed; ask the speech owner before changing them.

```json
{
  "word_id": "w_001",
  "decision": "accepted | needs_remediation",
  "score": 0.231,
  "threshold": 0.298,
  "threshold_source": "bank | fallback",
  "nearest_variant": "spk_adult_02",
  "segments": [{"label": "ම", "start_s": 0.31, "end_s": 0.52, "status": "ok | flagged", "cost": 0.41, "error_type": "substitution|omission|insertion|distortion|null"}],
  "latency_ms": {"load": 0, "embed": 0, "dtw": 0, "total": 0}
}
```

Errors return `{"detail": "..."}` with one of these statuses:

| Status | Cause |
|---|---|
| `400` | Unreadable, silent, too-short or too-long audio |
| `404` | Unknown `word_id` |
| `413` | File too large |
| `422` | Bad form fields: wrong or invalid `language`, or a `child_id` that isn't a UUID |
| `503` | The speech service is down, or the word has no reference recordings yet |
| `502` | Any other speech service error |

**Current stage (Stage 3):**
- Scoring uses every reference recording of the word. `threshold_source` is `"bank"` when the word has at least 4 references (the range is learned from them) and `"fallback"` otherwise. `segments` is always `[]` until Stage 4.
- The endpoint is stateless. The app records each scored word through the shared offline queue (`component_name: "speech"`, `activity_id: "speech_word:<word_id>"`).

The internal speech service (`ml/speech`, port 8001) exposes `POST /assess` (the same fields without `child_id`) and `GET /health`. Its interactive docs are at `http://localhost:8001/docs`.
