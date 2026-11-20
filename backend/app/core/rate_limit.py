import base64
import hashlib
import json

from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.requests import Request

from app.core.config import settings


def _extract_jwt_sub(auth_header: str) -> str | None:
    parts = auth_header.split(None, 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return None
    segments = parts[1].split(".")
    if len(segments) != 3:
        return None
    try:
        padded = segments[1] + "=" * (-len(segments[1]) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded))
        sub = payload.get("sub")
        return str(sub) if sub else None
    except Exception:
        return None


def ocr_rate_key(request: Request) -> str:
    ip = get_remote_address(request)
    auth = (request.headers.get("authorization") or "").strip()
    if not auth:
        return f"{ip}:anon"
    sub = _extract_jwt_sub(auth)
    if sub:
        return f"{ip}:u:{sub}"
    digest = hashlib.sha256(auth.encode("utf-8")).hexdigest()[:16]
    return f"{ip}:t:{digest}"


limiter = Limiter(key_func=ocr_rate_key)


def ocr_limit_string() -> str:
    return f"{settings.ocr_rate_limit_per_minute}/minute"
