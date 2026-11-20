from __future__ import annotations

import logging
from datetime import UTC, date, datetime
from typing import Any

from fastapi import HTTPException, status

from app.core.config import settings
from app.core.security import CurrentUser
from app.models.schemas import (
    WarrantyCreate,
    WarrantyOut,
    WarrantyUpdate,
    expiration_from,
    lifecycle_status,
)
from app.services.storage import remove_objects, sign_user_object
from app.services.supabase_client import service_client, user_client

logger = logging.getLogger(__name__)
_MAX_KNOWN_PROFILES = 10_000


def _parse_date(value: Any) -> date:
    if isinstance(value, date) and not isinstance(value, datetime):
        return value
    return datetime.strptime(str(value)[:10], "%Y-%m-%d").date()


def row_to_out(
    row: dict[str, Any],
    user: CurrentUser | None = None,
    client: Any | None = None,
) -> WarrantyOut:
    exp = _parse_date(row["warranty_expiration_date"])
    days, status_name = lifecycle_status(exp)
    price = row.get("price_paid")
    receipt_url = row["receipt_image_url"]
    receipt_path = row.get("receipt_image_path")
    serial_url = row.get("serial_image_url")
    serial_path = row.get("serial_image_path")

    if user is not None:
        receipt_target = receipt_path or receipt_url
        signed_receipt = sign_user_object(
            user, settings.supabase_receipts_bucket, receipt_target, client=client
        )
        if signed_receipt:
            receipt_url = signed_receipt
        serial_target = serial_path or serial_url
        if serial_target:
            signed_serial = sign_user_object(
                user, settings.supabase_serials_bucket, serial_target, client=client
            )
            if signed_serial:
                serial_url = signed_serial

    return WarrantyOut(
        id=str(row["id"]),
        user_id=str(row["user_id"]),
        item_name=row["item_name"],
        merchant_name=row.get("merchant_name"),
        category=row.get("category") or "Consumer Tech",
        purchase_date=_parse_date(row["purchase_date"]),
        warranty_duration_months=int(row.get("warranty_duration_months") or 12),
        warranty_expiration_date=exp,
        serial_number=row.get("serial_number"),
        price_paid=float(price) if price is not None else None,
        currency=row.get("currency") or "USD",
        receipt_image_url=receipt_url,
        receipt_image_path=receipt_path,
        serial_image_url=serial_url,
        serial_image_path=serial_path,
        notes=row.get("notes"),
        days_remaining=days,
        status=status_name,
    )


_known_profiles: set[str] = set()


def _remember_profile(user_id: str) -> None:
    if len(_known_profiles) >= _MAX_KNOWN_PROFILES:
        _known_profiles.clear()
    _known_profiles.add(user_id)


def ensure_profile(user: CurrentUser) -> None:
    if user.id in _known_profiles:
        return
    client = user_client(user)
    existing = client.table("profiles").select("id").eq("id", user.id).limit(1).execute()
    if existing.data:
        _remember_profile(user.id)
        return
    try:
        svc = service_client()
    except RuntimeError as exc:
        logger.warning("Cannot backfill profile for %s: %s", user.id, exc)
        return
    svc.table("profiles").upsert(
        {"id": user.id, "email": user.email or ""},
        on_conflict="id",
    ).execute()
    _remember_profile(user.id)


def create_warranty(user: CurrentUser, body: WarrantyCreate) -> WarrantyOut:
    ensure_profile(user)
    exp = body.warranty_expiration_date or expiration_from(
        body.purchase_date, body.warranty_duration_months
    )
    payload = {
        "user_id": user.id,
        "item_name": body.item_name,
        "merchant_name": body.merchant_name,
        "category": body.category,
        "purchase_date": body.purchase_date.isoformat(),
        "warranty_duration_months": body.warranty_duration_months,
        "warranty_expiration_date": exp.isoformat(),
        "serial_number": body.serial_number,
        "price_paid": body.price_paid,
        "currency": body.currency,
        "receipt_image_url": body.receipt_image_url,
        "receipt_image_path": body.receipt_image_path,
        "serial_image_url": body.serial_image_url,
        "serial_image_path": body.serial_image_path,
        "notes": body.notes,
    }
    client = user_client(user)
    result = client.table("warranties").insert(payload).execute()
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not save the warranty right now. Please try again.",
        )
    return row_to_out(result.data[0], user=user)


def _fetch(user: CurrentUser, warranty_id: str) -> dict[str, Any]:
    client = user_client(user)
    result = (
        client.table("warranties")
        .select("*")
        .eq("id", warranty_id)
        .eq("user_id", user.id)
        .limit(1)
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Warranty not found")
    return result.data[0]


def list_warranties(
    user: CurrentUser,
    q: str | None,
    category: str | None,
) -> list[WarrantyOut]:
    client = user_client(user)
    query = client.table("warranties").select("*").eq("user_id", user.id)
    if category:
        query = query.eq("category", category)
    result = query.order("warranty_expiration_date").execute()
    rows = result.data or []
    if q:
        needle = q.strip().lower()
        rows = [
            r
            for r in rows
            if needle in (r.get("item_name") or "").lower()
            or needle in (r.get("merchant_name") or "").lower()
            or needle in (r.get("serial_number") or "").lower()
        ]
    return [row_to_out(r, user=user, client=client) for r in rows]


def get_warranty(user: CurrentUser, warranty_id: str) -> WarrantyOut:
    return row_to_out(_fetch(user, warranty_id), user=user)


def update_warranty(user: CurrentUser, warranty_id: str, body: WarrantyUpdate) -> WarrantyOut:
    existing = _fetch(user, warranty_id)
    patch = body.model_dump(exclude_unset=True)
    if not patch:
        return row_to_out(existing, user=user)
    purchase = patch.get("purchase_date") or _parse_date(existing["purchase_date"])
    months = patch.get("warranty_duration_months") or int(existing["warranty_duration_months"])
    if "purchase_date" in patch or "warranty_duration_months" in patch:
        if "warranty_expiration_date" not in patch:
            patch["warranty_expiration_date"] = expiration_from(purchase, months)
    serialized: dict[str, Any] = {}
    for key, value in patch.items():
        if hasattr(value, "isoformat"):
            serialized[key] = value.isoformat()
        else:
            serialized[key] = value
    serialized["updated_at"] = datetime.now(UTC).isoformat()
    client = user_client(user)
    result = (
        client.table("warranties")
        .update(serialized)
        .eq("id", warranty_id)
        .eq("user_id", user.id)
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not save your changes right now. Please try again.",
        )
    return row_to_out(result.data[0], user=user)


def delete_warranty(user: CurrentUser, warranty_id: str) -> None:
    row = _fetch(user, warranty_id)
    remove_objects(
        user,
        settings.supabase_receipts_bucket,
        [row.get("receipt_image_path") or row.get("receipt_image_url")],
    )
    remove_objects(
        user,
        settings.supabase_serials_bucket,
        [row.get("serial_image_path") or row.get("serial_image_url")],
    )
    client = user_client(user)
    client.table("warranties").delete().eq("id", warranty_id).eq("user_id", user.id).execute()

