# Feature: Expiry notifications

**SRS:** §3.5 FR-NOTIF-01..02, CI-03  
**Priority:** P1 (custom times P2)  
**Status:** Specified only — **not implemented** in this backend increment

## Intent

Push (and/or local) alerts at 30 days, 7 days, and 24 hours before `warranty_expiration_date`.

## Planned design (later gate)

- Flutter: schedule local notifications for guest + as a fallback.
- Registered users: FCM (Android) / APNs (iOS) via a worker that scans warranties daily.
- FR-NOTIF-02: per-user toggles on `profiles` (columns not in SRS schema yet — add in that gate).

## Out of scope now

No FCM server key, no dispatcher job, no settings API.
