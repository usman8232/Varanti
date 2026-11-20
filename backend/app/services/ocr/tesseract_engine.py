from __future__ import annotations

import io
import logging

from PIL import Image

from app.core.config import settings

logger = logging.getLogger(__name__)


def extract_text(image_bytes: bytes) -> str:
    try:
        import pytesseract
    except ImportError:
        logger.warning("pytesseract is not installed")
        return ""

    if settings.tesseract_cmd:
        pytesseract.pytesseract.tesseract_cmd = settings.tesseract_cmd

    try:
        image = Image.open(io.BytesIO(image_bytes))
        if image.mode not in ("RGB", "L"):
            image = image.convert("RGB")
        text = pytesseract.image_to_string(image)
        return (text or "").strip()
    except Exception as exc:
        logger.warning("Tesseract failed: %s", exc)
        return ""
