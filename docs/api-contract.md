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

## Auth

There is no authentication on these endpoints. `child_id` is trusted as sent by the client. This is intentional for the MVP — see [decision-log.md](decision-log.md) for the reasoning.

## `component_name` values

Use one of: `"handwriting"`, `"speech"`, `"spelling"`, `"math_memory"`. This is a free-text field, not an enum, so a new component can be added without a migration — but stick to these four names for consistency.
