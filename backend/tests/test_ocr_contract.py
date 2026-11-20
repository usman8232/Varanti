from datetime import date
from unittest.mock import patch

from app.models.schemas import ExtractedFields, ImageRefs
from app.services.ocr.pipeline import run_hybrid_ocr


def test_ocr_success_contract():
    images = ImageRefs(
        receipt_path="user/a.jpg",
        receipt_image_url="https://example.supabase.co/storage/v1/object/public/receipts/user/a.jpg",
    )
    extracted = ExtractedFields(
        merchant_name="Store",
        purchase_date=date(2026, 1, 15),
        item_name="Headphones",
        serial_number="SN1",
        warranty_duration_months=24,
        total_amount=None,
        currency="USD",
    )
    with (
        patch("app.services.ocr.pipeline.extract_text", return_value="Store\nHeadphones"),
        patch("app.services.ocr.pipeline.extract_structured", return_value=extracted),
    ):
        result = run_hybrid_ocr(
            receipt_bytes=b"fake",
            receipt_mime="image/jpeg",
            serial_bytes=None,
            serial_mime=None,
            images=images,
        )
    payload = result.model_dump()
    assert payload["ocr_failed"] is False
    assert payload["raw_text"] == "Store\nHeadphones"
    assert payload["extracted"]["item_name"] == "Headphones"
    assert payload["warranty_expiration_date"] == date(2028, 1, 15)
    assert "receipt_image_url" in payload["images"]


def test_ocr_failure_is_manual_form():
    images = ImageRefs(receipt_path="user/a.jpg", receipt_image_url="https://example/a.jpg")
    with (
        patch("app.services.ocr.pipeline.extract_text", return_value=""),
        patch(
            "app.services.ocr.pipeline.extract_structured",
            side_effect=RuntimeError("quota"),
        ),
    ):
        result = run_hybrid_ocr(
            receipt_bytes=b"fake",
            receipt_mime="image/jpeg",
            serial_bytes=None,
            serial_mime=None,
            images=images,
        )
    assert result.ocr_failed is True
    assert not result.extracted.item_name
    assert result.warranty_expiration_date is None

    assert result.images.receipt_image_url is not None
