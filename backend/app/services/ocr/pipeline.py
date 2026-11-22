from __future__ import annotations

import asyncio

from fastapi import HTTPException, UploadFile, status

from app.core.config import settings
from app.core.security import CurrentUser
from app.models.schemas import ExtractedFields, ImageUrls, OcrScanResponse, expiration_from
from app.services.ocr.gemini_engine import extract_structured
from app.services.ocr.tesseract_engine import extract_text
from app.services.storage import _normalize_mime, remove_objects, upload_user_image

MAX_BYTES = 8 * 1024 * 1024


async def _read_upload(file: UploadFile | None) -> tuple[bytes, str, str] | None:
    if file is None:
        return None
    data = await file.read()
    if not data:
        return None
    if len(data) > MAX_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Image exceeds 8 MB",
        )
    mime = file.content_type or "image/jpeg"
    name = file.filename or "upload.jpg"
    return data, mime, name


def run_hybrid_ocr(
    *,
    receipt_bytes: bytes,
    receipt_mime: str,
    serial_bytes: bytes | None = None,
    serial_mime: str | None = None,
    images: ImageUrls,
) -> OcrScanResponse:
    try:
        raw_text = extract_text(receipt_bytes)
    except Exception:
        raw_text = ""

    try:
        extracted = extract_structured(
            receipt_bytes,
            receipt_mime,
            raw_text,
            serial_bytes,
            serial_mime,
        )
    except Exception:
        extracted = None

    ocr_failed = extracted is None
    if extracted is None:
        extracted = ExtractedFields(item_name="")

    needs_review = ocr_failed or not extracted.item_name or extracted.purchase_date is None
    expiration = None
    if extracted.purchase_date:
        expiration = expiration_from(extracted.purchase_date, extracted.warranty_duration_months)

    return OcrScanResponse(
        images=images,
        raw_text=raw_text,
        extracted=extracted,
        warranty_expiration_date=expiration,
        ocr_failed=ocr_failed,
        needs_review=needs_review,
    )


async def upload_warranty_images(
    user: CurrentUser,
    receipt: UploadFile,
    serial: UploadFile | None = None,
) -> ImageUrls:
    receipt_tuple = await _read_upload(receipt)
    if not receipt_tuple:
        raise HTTPException(status_code=400, detail="Receipt image is required")
    receipt_bytes, receipt_mime, receipt_name = receipt_tuple
    serial_tuple = await _read_upload(serial)

    # Validate MIME types up front so an invalid serial photo never leaves an orphaned receipt
    _normalize_mime(receipt_mime, receipt_name)
    if serial_tuple:
        _normalize_mime(serial_tuple[1], serial_tuple[2])

    receipt_path, receipt_url = await asyncio.to_thread(
        upload_user_image,
        user,
        settings.supabase_receipts_bucket,
        "receipts",
        receipt_bytes,
        receipt_mime,
        receipt_name,
    )
    serial_path = serial_url = None
    if serial_tuple:
        serial_bytes, serial_mime, serial_name = serial_tuple
        try:
            serial_path, serial_url = await asyncio.to_thread(
                upload_user_image,
                user,
                settings.supabase_serials_bucket,
                "serials",
                serial_bytes,
                serial_mime,
                serial_name,
            )
        except Exception:
            await asyncio.to_thread(
                remove_objects,
                user,
                settings.supabase_receipts_bucket,
                [receipt_path],
            )
            raise

    return ImageUrls(
        receipt_url=receipt_url,
        receipt_path=receipt_path,
        serial_url=serial_url,
        serial_path=serial_path,
    )


async def run_scan(
    user: CurrentUser,
    receipt: UploadFile,
    serial: UploadFile | None,
) -> OcrScanResponse:
    receipt_tuple = await _read_upload(receipt)
    if not receipt_tuple:
        raise HTTPException(status_code=400, detail="Receipt image is required")
    receipt_bytes, receipt_mime, receipt_name = receipt_tuple
    serial_tuple = await _read_upload(serial)

    # Pre-validate both files before uploading either
    _normalize_mime(receipt_mime, receipt_name)
    if serial_tuple:
        _normalize_mime(serial_tuple[1], serial_tuple[2])

    receipt_path, receipt_url = await asyncio.to_thread(
        upload_user_image,
        user,
        settings.supabase_receipts_bucket,
        "receipts",
        receipt_bytes,
        receipt_mime,
        receipt_name,
    )
    serial_path = serial_url = None
    serial_bytes = serial_mime = None
    if serial_tuple:
        serial_bytes, serial_mime, serial_name = serial_tuple
        try:
            serial_path, serial_url = await asyncio.to_thread(
                upload_user_image,
                user,
                settings.supabase_serials_bucket,
                "serials",
                serial_bytes,
                serial_mime,
                serial_name,
            )
        except Exception:
            await asyncio.to_thread(
                remove_objects,
                user,
                settings.supabase_receipts_bucket,
                [receipt_path],
            )
            raise

    images = ImageUrls(
        receipt_url=receipt_url,
        receipt_path=receipt_path,
        serial_url=serial_url,
        serial_path=serial_path,
    )
    return await asyncio.to_thread(
        run_hybrid_ocr,
        receipt_bytes=receipt_bytes,
        receipt_mime=receipt_mime,
        serial_bytes=serial_bytes,
        serial_mime=serial_mime,
        images=images,
    )

