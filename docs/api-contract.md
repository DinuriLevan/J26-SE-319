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
| `POST` | `/speech/assess-unit` | Speech remediation: score one unit or a blend. Multipart: `audio`, `word_id`, `language`, `start_unit`, `end_unit` (inclusive unit indices), `child_id`. Returns `{word_id, start_unit, end_unit, label, decision, score, threshold, threshold_source, latency_ms}`. Single-unit attempts are recorded in `phoneme_progress` |
| `GET` | `/speech/progress/{child_id}` | Speech: the child's per-unit practice record `[{child_id, language, unit_label, attempts, successes, last_score, last_seen, mastery}]`, lowest mastery first. `mastery` = moving average of pass/fail (alpha 0.3) |
| `GET` | `/speech/words` | Speech: `[{word_id, text, language, units, listen_units, has_word_audio, n_refs, n_speakers}]`. `listen_units` = units with adult model audio. A word is **ready** for children when `n_refs >= 4` (learned pass mark) |
| `GET` | `/speech/listen/{word_id}?start_unit=&end_unit=` | Speech: **adult** model audio (WAV) for the Listen step, either a unit span or the whole word. 404 when the word has no adult recording. Children's recordings are never served |
| `POST` | `/speech/references` | **Developer tool**, speech: add an **adult** reference recording to the bank. The speech service returns 404 unless started with `SPEECH_ALLOW_REFERENCE_UPLOAD=1`, and 422 for any `age_group` other than `adult`. Fields: `audio`, `word_id`, `language`, `speaker_id` (`[a-z0-9_]{1,32}`), `age_group`, `accent`. No child id |

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
  "threshold_source": "shared | bank | fallback",
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

**Rewards (Stage 5):** after a word is mastered, the app unlocks a milestone card in the shared album via `POST /rewards/{child_id}/unlock` with `card_id = "speech_words_<N>"` for every 5th different word mastered (5, 10, 15, ...). Each finished word (mastered or fallback) writes one `ActivityResult` (`component_name: "speech"`, `activity_id: "speech_word:<word_id>"`) through the shared offline queue. Its payload holds `outcome` (`mastered` or `fallback`), attempt counts, `flagged_units`, `practise_later` and the loop events.

**Current stage (Stage 4):**
- Scoring uses every reference recording of the word. `threshold_source` is `"shared"` when the service uses one pass mark per language (the default since 2026-10-20). With the per-word setting it is `"bank"` when the word has at least 4 references (the range is learned from them) and `"fallback"` otherwise. Unit attempts (`/speech/assess-unit`) still use `"bank"` / `"fallback"`.
- `segments` is `[]` when the attempt is accepted. Otherwise it lists every unit of the word (Sinhala akshara, English letter chunks such as `c|a|t`) on the child's timeline. The worst unit, and the second worst if close, has `status: "flagged"` and an `error_type`. Error types are rule-based and not yet validated.
- The endpoint is stateless. The app records each scored word through the shared offline queue (`component_name: "speech"`, `activity_id: "speech_word:<word_id>"`).

The internal speech service (`ml/speech`, port 8001) exposes `POST /assess` (the same fields without `child_id`) and `GET /health`. Its interactive docs are at `http://localhost:8001/docs`.
