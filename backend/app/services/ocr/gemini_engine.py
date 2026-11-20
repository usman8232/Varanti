from __future__ import annotations

import json
import logging
import re
from datetime import date, datetime
from typing import Any

from app.core.config import settings
from app.models.schemas import ExtractedFields

logger = logging.getLogger(__name__)

PROMPT = """You extract warranty fields from a store receipt (and optional serial-label photo).
Use the Tesseract raw text as a hint; prefer the images if they disagree.
Return JSON only with this shape:
{{
  "merchant_name": string or null,
  "purchase_date": "YYYY-MM-DD" or null,
  "item_name": string (empty if unknown),
  "serial_number": string or null,
  "warranty_duration_months": integer (12 if not listed),
  "total_amount": number or null,
  "currency": 3-letter ISO-4217 code (USD if unknown)
}}
Do not invent a serial number. Do not include markdown.
Tesseract raw text:
---
{raw_text}
---
"""


def _parse_date(value: Any) -> date | None:
    if value is None or value == "":
        return None
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    text = str(value)[:10]
    try:
        return datetime.strptime(text, "%Y-%m-%d").date()
    except ValueError:
        return None


def _as_fields(data: dict[str, Any]) -> ExtractedFields:
    months = data.get("warranty_duration_months") or 12
    try:
        months = int(months)
    except (TypeError, ValueError):
        months = 12
    months = max(1, min(months, 600))
    amount = data.get("total_amount")
    try:
        amount = float(amount) if amount is not None and amount != "" else None
    except (TypeError, ValueError):
        amount = None
    currency = (data.get("currency") or "USD")[:3].upper()
    if len(currency) != 3:
        currency = "USD"
    item = data.get("item_name") or ""
    return ExtractedFields(
        merchant_name=data.get("merchant_name") or None,
        purchase_date=_parse_date(data.get("purchase_date")),
        item_name=str(item),
        serial_number=data.get("serial_number") or None,
        warranty_duration_months=months,
        total_amount=amount,
        currency=currency,
    )


def extract_structured(
    receipt_bytes: bytes,
    receipt_mime: str,
    raw_text: str,
    serial_bytes: bytes | None = None,
    serial_mime: str | None = None,
) -> ExtractedFields | None:
    if not settings.gemini_configured:
        logger.warning("GEMINI_API_KEY is not set")
        return None
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        logger.warning("google-genai is not installed")
        return None

    client = genai.Client(api_key=settings.gemini_api_key)
    parts: list[Any] = [
        types.Part.from_bytes(data=receipt_bytes, mime_type=receipt_mime or "image/jpeg"),
        PROMPT.format(raw_text=raw_text or "(none)"),
    ]
    if serial_bytes:
        parts.insert(
            1,
            types.Part.from_bytes(
                data=serial_bytes,
                mime_type=serial_mime or "image/jpeg",
            ),
        )
    try:
        response = client.models.generate_content(
            model=settings.gemini_model,
            contents=parts,
            config=types.GenerateContentConfig(response_mime_type="application/json"),
        )
        text = (response.text or "").strip()
        text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)
        data = json.loads(text)
        if not isinstance(data, dict):
            return None
        return _as_fields(data)
    except Exception as exc:
        logger.warning("Gemini extraction failed: %s", exc)
        return None
