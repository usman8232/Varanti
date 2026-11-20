from __future__ import annotations

import logging
import uuid

from fastapi import HTTPException, status

from app.core.security import CurrentUser
from app.services.supabase_client import user_client

logger = logging.getLogger(__name__)

ALLOWED_TYPES = {
    "image/jpeg": "jpg",
    "image/jpg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "image/heic": "heic",
    "image/heif": "heif",
}

_EXT_TO_MIME = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
    "heic": "image/heic",
    "heif": "image/heif",
}

DEFAULT_SIGNED_URL_TTL_SECONDS = 60 * 60 * 24 * 7


def _normalize_mime(content_type: str | None, filename: str | None) -> str:
    ct = (content_type or "").split(";")[0].strip().lower()
    if ct in ALLOWED_TYPES:
        return ct
    if not ct or ct == "application/octet-stream":
        if filename and "." in filename:
            ext = filename.rsplit(".", 1)[-1].lower()
            if ext in _EXT_TO_MIME:
                return _EXT_TO_MIME[ext]
        return "image/jpeg"
    raise HTTPException(
        status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
        detail="That image format isn't supported. Please use JPG, PNG, or WebP.",
    )


def _extract_signed_url(signed: object) -> str | None:
    if not isinstance(signed, dict):
        return None
    url = signed.get("signedURL") or signed.get("signedUrl") or signed.get("signed_url")
    if isinstance(url, dict):
        url = url.get("signedUrl") or url.get("signedURL")
    return str(url) if url else None


def upload_user_image(
    user: CurrentUser,
    bucket: str,
    folder: str,
    data: bytes,
    content_type: str | None,
    filename: str | None,
) -> tuple[str, str]:
    """Returns (path, signed_url). Path is `{user_id}/{folder}/{uuid}.ext`."""
    mime = _normalize_mime(content_type, filename)
    ext = ALLOWED_TYPES[mime]
    path = f"{user.id}/{folder}/{uuid.uuid4()}.{ext}"
    client = user_client(user)
    file_options = {"content-type": mime, "upsert": "false"}
    try:
        client.storage.from_(bucket).upload(path, data, file_options=file_options)
        signed = client.storage.from_(bucket).create_signed_url(
            path, DEFAULT_SIGNED_URL_TTL_SECONDS
        )
    except Exception as exc:
        logger.warning("Storage upload failed for %s/%s: %s", bucket, path, exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not upload your image right now. Please try again.",
        ) from exc
    url = _extract_signed_url(signed) or path
    return path, url


def storage_path_from_url(url_or_path: str, bucket: str) -> str:
    """Extract object path relative to the bucket from a storage URL or return path as-is."""
    marker = f"/{bucket}/"
    if marker in url_or_path:
        return url_or_path.split(marker, 1)[1].split("?")[0]
    return url_or_path


def sign_user_object(
    user: CurrentUser,
    bucket: str,
    path_or_url: str | None,
    expires_in: int = DEFAULT_SIGNED_URL_TTL_SECONDS,
    client: object | None = None,
) -> str | None:
    """Generate a fresh signed URL for a private bucket object owned by `user`."""
    if not path_or_url:
        return None
    marker = f"/{bucket}/"
    if path_or_url.startswith(("http://", "https://")) and marker not in path_or_url:
        return path_or_url
    obj_path = storage_path_from_url(path_or_url, bucket)
    if not obj_path or obj_path.startswith(("http://", "https://", "/")):
        return path_or_url
    try:
        sb = client or user_client(user)
        signed = sb.storage.from_(bucket).create_signed_url(obj_path, expires_in)
        return _extract_signed_url(signed) or path_or_url
    except Exception as exc:
        logger.warning("Failed to re-sign storage object %s/%s: %s", bucket, obj_path, exc)
        return path_or_url


def remove_objects(user: CurrentUser, bucket: str, paths: list[str | None]) -> None:
    cleaned: list[str] = []
    prefix = f"{user.id}/"
    for p in paths:
        if not p:
            continue
        candidate = storage_path_from_url(p, bucket)
        if candidate.startswith(prefix):
            cleaned.append(candidate)
    if not cleaned:
        return
    client = user_client(user)
    try:
        client.storage.from_(bucket).remove(cleaned)
    except Exception as exc:
        logger.warning("Failed to remove storage objects %s from %s: %s", cleaned, bucket, exc)

