# Feature: OCR and intelligent extraction

**SRS:** §3.3 FR-OCR-01..04, NFR-PERF-01, reliability NFR  
**Priority:** P1  
**Status:** Implemented as `POST /v1/ocr/scan`

## Intent

Turn a receipt image into editable structured fields. **Do not insert a warranty until the client confirms** via `POST /v1/warranties`.

## Pipeline (hybrid)

1. Authenticate JWT.
2. Rate-limit by IP and user id (`OCR_RATE_LIMIT_PER_MINUTE`).
3. Upload images to Storage.
4. Tesseract → `raw_text`.
5. Gemini Flash sees the image plus `raw_text` and must return JSON matching the field list.
6. Compute `warranty_expiration_date` from purchase date + duration months (default 12).
7. If Tesseract or Gemini fails: still return 200 with `ocr_failed: true` and empty/default fields so Flutter can show a manual form (image URLs attached).

## Fields (FR-OCR-02)

| Field | Type | Notes |
| --- | --- | --- |
| merchant_name | string, nullable | |
| purchase_date | ISO-8601 date | If missing after OCR, leave null and set `ocr_failed` or `needs_review` |
| item_name | string | Empty string if unknown |
| serial_number | string, nullable | May come from serial photo |
| warranty_duration_months | int | Default 12 |
| total_amount | decimal, nullable | Maps to `price_paid` |
| currency | ISO-4217 | Default USD |

## API

`POST /v1/ocr/scan`  
Auth: Bearer  
Body: multipart `receipt` file, optional `serial` file  
Success JSON: `images`, `raw_text`, `extracted`, `warranty_expiration_date`, `ocr_failed`, `needs_review`

Latency target: 4 seconds on typical networks (NFR-PERF-01). Not guaranteed on free-tier cold starts.

## Flutter (later)

Editable confirmation modal (FR-OCR-04) before save. Max three taps for the happy path is a UX constraint, not an API constraint.
