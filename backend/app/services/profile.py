from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime
from typing import Any

from fastapi import HTTPException, UploadFile, status

from app.core.config import settings
from app.core.security import CurrentUser
from app.models.schemas import ProfileOut, ProfileUpdate
from app.services.storage import (
    _normalize_mime,
    remove_objects,
    sign_user_object,
    upload_user_image,
)
from app.services.supabase_client import user_client
from app.services.warranties import ensure_profile

logger = logging.getLogger(__name__)
MAX_AVATAR_BYTES = 4 * 1024 * 1024


def _row_to_profile(
    row: dict[str, Any],
    user: CurrentUser,
    client: Any | None = None,
) -> ProfileOut:
    avatar_path = row.get("avatar_path")
    avatar_url = row.get("avatar_url")
    if avatar_path:
        signed = sign_user_object(
            user,
            settings.supabase_avatars_bucket,
            avatar_path,
            client=client,
        )
        if signed:
            avatar_url = signed
    return ProfileOut(
        id=str(row.get("id") or user.id),
        email=row.get("email") or user.email or "",
        full_name=row.get("full_name"),
        phone=row.get("phone") or user.phone,
        avatar_url=avatar_url,
        avatar_path=avatar_path,
    )


def get_profile(user: CurrentUser) -> ProfileOut:
    ensure_profile(user)
    client = user_client(user)
    result = (
        client.table("profiles")
        .select("*")
        .eq("id", user.id)
        .limit(1)
        .execute()
    )
    if not result.data:
        return ProfileOut(id=user.id, email=user.email or "", phone=user.phone)
    return _row_to_profile(result.data[0], user, client=client)


def update_profile(user: CurrentUser, body: ProfileUpdate) -> ProfileOut:
    ensure_profile(user)
    patch = body.model_dump(exclude_unset=True)
    if not patch:
        return get_profile(user)

    cleaned: dict[str, Any] = {}
    for key, value in patch.items():
        if isinstance(value, str):
            trimmed = value.strip()
            cleaned[key] = trimmed if trimmed else None
        else:
            cleaned[key] = value
    cleaned["updated_at"] = datetime.now(UTC).isoformat()

    client = user_client(user)
    try:
        result = (
            client.table("profiles")
            .update(cleaned)
            .eq("id", user.id)
            .execute()
        )
    except Exception as exc:
        # Graceful fallback if migration 0004 (phone/avatar_url) has not yet been applied
        logger.warning("Full profile update failed (%s); retrying base columns", exc)
        fallback_payload = {
            k: v
            for k, v in cleaned.items()
            if k in ("full_name", "updated_at")
        }
        result = (
            client.table("profiles")
            .update(fallback_payload)
            .eq("id", user.id)
            .execute()
        )

    if not result.data:
        return get_profile(user)
    return _row_to_profile(result.data[0], user, client=client)


async def upload_profile_avatar(user: CurrentUser, avatar: UploadFile) -> ProfileOut:
    data = await avatar.read()
    if not data:
        raise HTTPException(status_code=400, detail="Avatar image is required")
    if len(data) > MAX_AVATAR_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Avatar image exceeds 4 MB",
        )
    mime = avatar.content_type or "image/jpeg"
    name = avatar.filename or "avatar.jpg"
    _normalize_mime(mime, name)

    previous = await asyncio.to_thread(get_profile, user)
    avatar_path, avatar_url = await asyncio.to_thread(
        upload_user_image,
        user,
        settings.supabase_avatars_bucket,
        "avatar",
        data,
        mime,
        name,
    )

    client = user_client(user)
    now = datetime.now(UTC).isoformat()
    try:
        await asyncio.to_thread(
            lambda: client.table("profiles")
            .update(
                {
                    "avatar_url": avatar_url,
                    "avatar_path": avatar_path,
                    "updated_at": now,
                }
            )
            .eq("id", user.id)
            .execute()
        )
    except Exception as exc:
        logger.warning(
            "Could not persist avatar_path to profiles (run migration 0004): %s",
            exc,
        )

    if previous.avatar_path and previous.avatar_path != avatar_path:
        await asyncio.to_thread(
            remove_objects,
            user,
            settings.supabase_avatars_bucket,
            [previous.avatar_path],
        )

    return ProfileOut(
        id=previous.id,
        email=previous.email,
        full_name=previous.full_name,
        phone=previous.phone,
        avatar_url=avatar_url,
        avatar_path=avatar_path,
    )
