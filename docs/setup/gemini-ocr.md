# Connect Gemini Flash for OCR (you run these steps)

Hybrid pipeline: **Tesseract** (local, no Google key) then **Gemini Flash** (needs API key).

## 1. Tesseract on your machine

- Windows: install from [UB Mannheim builds](https://github.com/UB-Mannheim/tesseract/wiki) and add to PATH, or set `TESSERACT_CMD` to the `tesseract.exe` path.
- Docker image already installs `tesseract-ocr`.

No Tesseract → OCR still calls Gemini; `raw_text` may be empty; `ocr_failed` may be true if Gemini also fails.

## 2. Google AI Studio key

1. Open [Google AI Studio](https://aistudio.google.com/apikey) and create an API key.
2. Set in `backend/.env`:

```
GEMINI_API_KEY=...
GEMINI_MODEL=gemini-2.0-flash
```

If Google renames the Flash model, change `GEMINI_MODEL` only — no code change required.

Restrict the key to this backend if the console allows IP or API restriction.

## 3. What the backend sends

- Receipt image bytes (and serial image if present)
- Tesseract `raw_text`
- A schema prompt listing merchant, item, dates, serial, duration, amount, currency

Gemini must respond with JSON only. The API maps that JSON to the warranty field names.

## 4. Cost and abuse

OCR is rate-limited (`OCR_RATE_LIMIT_PER_MINUTE`). Gemini usage is billed to your Google account. There is no paywall in the app (SRS).

## 5. Smoke test

```bash
curl -X POST http://localhost:8000/v1/ocr/scan ^
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" ^
  -F "receipt=@sample-receipt.jpg"
```

Expect `extracted` fields and `images.receipt_url`. On failure, `ocr_failed: true` with image URLs still present.
