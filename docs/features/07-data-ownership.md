# Feature: Data ownership, backup, export, purge

**SRS:** §3.7 FR-DATA-01..02, FR-AUTH-04, NFR-COMP-01..02  
**Priority:** P1 backup; P2 bulk export and one-click account delete  
**Status:** Unlimited cloud rows + delete-with-storage in this increment; bulk export and full account delete later

## Rules

- No monetization, profiling, or ad-network sale of receipts (NFR-COMP-01).
- Registered users: unlimited backups in Supabase (FR-DATA-01).
- Delete item: remove DB row **and** storage objects immediately (NFR-COMP-02). Implemented on `DELETE /v1/warranties/{id}`.
- Account deletion: purge `profiles` (cascade warranties) + all files under `{user_id}/`. Later gate (FR-AUTH-04). SRS appendix mislabels this as FR-DATA-02.
- FR-DATA-02 [P2]: bulk download images + JSON/CSV. Later gate.

## Guest

Local SQLite only; user is responsible for device backups until they register.
