# Feature: User authentication and profiles

**SRS:** §3.1 FR-AUTH-01..04  
**Priority:** P1 (delete account P2)  
**Status:** Backend JWT verification in this increment; Flutter login/guest later

## Intent

Free account creation. Cloud APIs only for registered users. Guest mode is local and never calls FastAPI OCR or storage.

## Requirements

| ID | Rule |
| --- | --- |
| FR-AUTH-01 | Email/password, Apple, Google. This increment: **email/password in Supabase Auth**. OAuth later. |
| FR-AUTH-02 | Guest / offline local store. **Flutter SQLite only.** No anonymous Supabase. |
| FR-AUTH-03 | JWT via Supabase Auth, refresh on the client. FastAPI verifies `Authorization: Bearer`. |
| FR-AUTH-04 [P2] | One-click account + data deletion (GDPR/CCPA). Stub in data-ownership spec; not implemented yet. |

## Backend

- Extract `sub` (user UUID) and `email` from a valid HS256 JWT using `SUPABASE_JWT_SECRET`.
- Reject missing/invalid tokens with 401.
- `profiles` row is created by a database trigger on `auth.users` insert (see migrations). Do not let the client insert another user’s profile.

## Flutter (later)

- Email sign-up / sign-in via `supabase_flutter`.
- Store refresh/access tokens in EncryptedSharedPreferences (NFR-SEC-03).
- Guest: SQLite sandbox; prompt to register before any cloud sync.

## Acceptance

- Unauthenticated `POST /v1/ocr/scan` and warranty routes return 401.
- Authenticated requests see only rows where `auth.uid() = user_id` (RLS).
