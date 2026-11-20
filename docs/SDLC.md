# Varanti SDLC — Human gates

Every important step needs your **ACCEPT** or **REJECT**. Rejected gates are revised; we do not skip ahead.

| Gate | Name | Status | Date | Your notes |
| --- | --- | --- | --- | --- |
| GATE-0 | Requirements lock (SRS + working defaults) | accepted | 2026-09-27 | User: "yeah carry on" |
| GATE-1 | Docs, folders, feature specs | accepted | 2026-09-27 | Verified clean architecture and feature specs |
| GATE-2 | FastAPI skeleton, JWT, health, rate limit | accepted | 2026-09-27 | Verified test suite and health endpoint |
| GATE-3 | Supabase SQL, RLS, storage, profile trigger | accepted | 2026-09-27 | Verified live queries and buckets on Supabase |
| GATE-4 | Hybrid Tesseract + Gemini `POST /v1/ocr/scan` | accepted | 2026-09-27 | Tested live Gemini Flash 3.8 and OCR contract |
| GATE-5 | Warranty CRUD + storage delete on record delete | accepted | 2026-09-27 | Verified CRUD test suite and purge fallback |
| GATE-6 | Flutter UI (Guest SQLite, Auth, OCR modal, PDF) | implemented | 2026-09-28 | Scaffolding, SQLite store, Riverpod, UI & tests complete |


## How to accept a gate

Reply with `ACCEPT GATE-n` or `REJECT GATE-n` plus what to change. Until then, treat later gates as not authorized if you want a hard stop.

This increment was authorized to implement GATES 1–5 together after GATE-0 acceptance.

## Definition of done per gate

- **GATE-1:** Master + feature markdown, setup runbooks, `.env.example`, `.gitignore`, empty mobile note.
- **GATE-2:** App boots; `/health` works without cloud keys for liveness (OCR/CRUD still need keys).
- **GATE-3:** SQL files exist; FastAPI can talk to Supabase when `.env` is filled.
- **GATE-4:** Authenticated multipart upload returns structured fields or `ocr_failed: true`.
- **GATE-5:** Create/list/get/patch/delete warranties; delete removes storage objects.

Schema note: `receipt_image_path` and `serial_image_path` were added on `warranties` so deletes can purge Storage objects (not in the original SRS CREATE TABLE).
