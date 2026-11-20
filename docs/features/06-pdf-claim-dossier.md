# Feature: PDF claim dossier

**SRS:** §3.6 FR-EXP-01..03, NFR-PERF-03  
**Priority:** P1  
**Status:** Specified only — **not implemented** in this increment

## Intent

On-demand unwatermarked A4 PDF: header (item, purchase date, merchant, status), serial, total, embedded receipt photo, optional serial photo, user contact block. Then native share sheet (Flutter).

## Planned design (later gate)

Decide device-side (Flutter `pdf` package, 2s target) vs FastAPI (WeasyPrint/ReportLab). SRS allows either.

## Out of scope now

No `/v1/warranties/{id}/dossier` route yet.
