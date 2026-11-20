# Varanti — Master Project Guide

Varanti is a free mobile utility that digitizes receipts, tracks product warranties, alerts before expiry, and exports unwatermarked claim PDFs. This file is the map of the repository, architecture, and how to run the backend.

## Authoritative sources

| Document | Role |
| --- | --- |
| `SRS-Varanti/Software Requirements Specification (SRS) - Varanti.pdf` | Approved requirements (IEEE 830 / ISO 29148), v1.1.0 |
| [SDLC.md](SDLC.md) | Human-gated development checklist |
| [features/](features/) | One spec per system feature |
| [setup/supabase.md](setup/supabase.md) | How you create and connect Supabase |
| [setup/gemini-ocr.md](setup/gemini-ocr.md) | How you create and connect Gemini Flash |

## Working defaults (GATE-0)

These filled truncated SRS fields. Change them only by explicit decision.

- Client JPEG quality **65**, max long edge **1600px**
- Warranty badge: **Active** if days remaining > 30; **Expiring Soon** if 1–30; **Expired** if ≤ 0
- `warranty_expiration_date` = `purchase_date` + `warranty_duration_months` (calendar months)
- Default duration **12** months; default currency **USD**
- Guest mode is **on-device SQLite only**; FastAPI requires a logged-in Supabase JWT
- Account/image purge is **FR-AUTH-04 / NFR-COMP-02**; bulk JSON/CSV export remains **FR-DATA-02 [P2]**

## Architecture

```
Flutter (camera, guest SQLite, confirmation UI)
    │  HTTPS JSON + Authorization: Bearer <access_token>
    ▼
FastAPI (JWT verify, rate limit, OCR orchestration, PDF later)
    │
    ├── Tesseract (raw text)
    ├── Gemini Flash (structured JSON)
    └── Supabase
          ├── Auth (JWT issuer)
          ├── PostgreSQL + RLS (profiles, warranties)
          └── Storage (receipts, serial-labels)
```

- Flutter uses the **anon key** + user JWT.
- FastAPI uses the **JWT secret** to verify tokens. The **service role key** stays on the server only and is used for Storage/DB operations that must still be scoped to `sub` from the JWT (never trust a client-supplied `user_id`).

## Repository layout

```
Varanti/
  SRS-Varanti/                 Approved SRS PDF
  docs/                        This guide, SDLC, feature specs, setup runbooks
  backend/                     FastAPI microservice
    app/                       Application package
    supabase/migrations/       SQL (tables, RLS, storage, profile trigger)
  mobile/                      Flutter app (scaffold later)
  .env.example                 Required environment variable names
```

## Feature map

| Feature | Spec | Backend owner now | Flutter later |
| --- | --- | --- | --- |
| Auth & profile | [features/01-authentication.md](features/01-authentication.md) | JWT gate, profile trigger | Login, guest SQLite |
| Image acquisition | [features/02-image-acquisition.md](features/02-image-acquisition.md) | Storage upload | Camera, gallery, compression |
| OCR | [features/03-ocr-extraction.md](features/03-ocr-extraction.md) | Hybrid pipeline | Confirmation modal |
| Warranties | [features/04-warranty-lifecycle.md](features/04-warranty-lifecycle.md) | CRUD API | Dashboard, badges |
| Notifications | [features/05-notifications.md](features/05-notifications.md) | Deferred | FCM + local |
| PDF dossier | [features/06-pdf-claim-dossier.md](features/06-pdf-claim-dossier.md) | Deferred | Share sheet |
| Data ownership | [features/07-data-ownership.md](features/07-data-ownership.md) | Delete + cascade | Export UI |

## Environment

Copy `.env.example` to `backend/.env` and fill values from Supabase and Google AI Studio. Never commit `.env`.

## Run the API (local)

Prerequisites: Python 3.11+, Tesseract OCR installed on the machine (or use Docker).

```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Docker (includes Tesseract):

```bash
cd backend
docker build -t varanti-api .
docker run --env-file .env -p 8000:8000 varanti-api
```

Health check: `GET http://localhost:8000/health`

OpenAPI: `http://localhost:8000/docs`

## Connect cloud services

You create the projects; the code reads keys from env.

1. Follow [setup/supabase.md](setup/supabase.md) — project, Auth, SQL migrations, buckets.
2. Follow [setup/gemini-ocr.md](setup/gemini-ocr.md) — API key and model id.
3. Restart FastAPI after editing `.env`.

## Constraints (SRS 2.5)

- No StoreKit, Play Billing, Stripe, or RevenueCat
- No ads, paywalls, or watermarks on PDFs
- OCR endpoints are rate-limited by IP and user id

## Current implementation status

See [SDLC.md](SDLC.md) for gate status. Backend increment covers health, OCR scan, and warranty CRUD. Notifications, PDF, OAuth providers, and Flutter UI wait for later accepted gates.
