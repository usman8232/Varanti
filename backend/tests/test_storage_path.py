import pytest
from fastapi import HTTPException

from app.services.storage import _normalize_mime, storage_path_from_url


def test_path_from_public_url():
    url = "https://xyz.supabase.co/storage/v1/object/public/receipts/uid/file.jpg"
    assert storage_path_from_url(url, "receipts") == "uid/file.jpg"


def test_path_passthrough():
    assert storage_path_from_url("uid/file.jpg", "receipts") == "uid/file.jpg"


def test_normalize_mime_infers_from_extension_for_octet_stream():
    assert _normalize_mime("application/octet-stream", "receipt.png") == "image/png"
    assert _normalize_mime("application/octet-stream", "photo.JPG") == "image/jpeg"
    assert _normalize_mime(None, "scan.webp") == "image/webp"


def test_normalize_mime_rejects_disallowed_type():
    with pytest.raises(HTTPException) as exc_info:
        _normalize_mime("application/pdf", "doc.pdf")
    assert exc_info.value.status_code == 415
