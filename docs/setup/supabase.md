# Connect Supabase (you run these steps)

FastAPI will not talk to a real project until you fill `backend/.env`.

## 1. Create the project

1. Open [https://supabase.com/dashboard](https://supabase.com/dashboard) and create a project (region close to you).
2. Wait until the database is ready.

## 2. Copy keys into `backend/.env`

Project **Settings → API**:

- `SUPABASE_URL` — Project URL
- `SUPABASE_ANON_KEY` — anon / public
- `SUPABASE_SERVICE_ROLE_KEY` — service_role (**server only**)

Project **Settings → API → JWT Secret**:

- `SUPABASE_JWT_SECRET`

Never commit these values. Never put the service role key in Flutter.

## 3. Auth

**Authentication → Providers:** enable **Email**.  
Leave Google/Apple off until the OAuth gate.

Optional: disable “Confirm email” in local/dev if you need faster testing.

## 4. Apply SQL

In **SQL Editor**, run the files in order:

1. `backend/supabase/migrations/0001_profiles_warranties_rls.sql`
2. `backend/supabase/migrations/0002_profile_trigger.sql`
3. `backend/supabase/migrations/0003_storage.sql`

Or use the Supabase CLI from `backend/` if you prefer: `supabase db push` (after linking).

## 5. Confirm buckets

`0003_storage.sql` creates private buckets `receipts` and `serial-labels`. Names must match `.env`:

```
SUPABASE_RECEIPTS_BUCKET=receipts
SUPABASE_SERIALS_BUCKET=serial-labels
```

## 6. Smoke test

1. Create a user in Authentication → Users (or sign up from a REST call).
2. Start FastAPI and `GET /health` — should show `supabase_configured: true` when URL and keys are set.
3. Sign in with password grant, copy `access_token`, call `GET /v1/warranties` with `Authorization: Bearer`.

## RLS rule of thumb

Policies use `auth.uid()`. If FastAPI used only the service role without setting the user, RLS would not apply. This API scopes Storage paths to `{jwt.sub}/...` and filters warranties by that id. Prefer passing the **user access token** into the Supabase client for table operations so Postgres RLS is enforced.
