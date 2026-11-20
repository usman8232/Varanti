# Feature: Warranty inventory and lifecycle

**SRS:** §3.4 FR-WAR-01..03, UI dashboard  
**Priority:** P1 (category filter P2)  
**Status:** CRUD API in this increment; badges/UI later

## Intent

Unlimited digital inventory. Color-coded remaining days. Full edit, search, tag, delete.

## Badge rules (working default)

Let `days = warranty_expiration_date - today` (UTC date).

- **Active** (green): days > 30
- **Expiring Soon** (amber): 1 ≤ days ≤ 30
- **Expired** (grey/red): days ≤ 0

API includes a computed `status` and `days_remaining` on read so Flutter does not reimplement the rule incorrectly.

## Categories

`Consumer Tech` | `Home Appliances` | `Computing` | `Audio` | `Power Tools` | `Other`  
Default: `Consumer Tech`. Filter endpoint query `?category=` is included for FR-WAR-03.

## API

All routes: Bearer JWT. RLS enforces ownership.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/v1/warranties` | Save after OCR confirm |
| GET | `/v1/warranties` | List; query `q`, `category` |
| GET | `/v1/warranties/{id}` | One record |
| PATCH | `/v1/warranties/{id}` | Edit |
| DELETE | `/v1/warranties/{id}` | Delete row + storage objects |

`notes` is the tag/free-text field for FR-WAR-02 until a dedicated tags table is accepted.

## Acceptance

- User A cannot read User B’s rows.
- No cap on row count (FR-DATA-01).
- Item 15 days from expiry → `status=expiring_soon` (SRS appendix).
