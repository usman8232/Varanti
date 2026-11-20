from datetime import date
from unittest.mock import patch
from fastapi.testclient import TestClient

from app.main import app
from app.models.schemas import WarrantyOut

client = TestClient(app)

MOCK_WARRANTY = WarrantyOut(
    id="e8a15993-21c6-487e-967b-4dca5f917573",
    user_id="user-123-uuid",
    item_name="Sony WH-1000XM5",
    merchant_name="Best Buy",
    category="Audio",
    purchase_date=date(2026, 1, 15),
    warranty_duration_months=12,
    warranty_expiration_date=date(2027, 1, 15),
    serial_number="SN-12345",
    price_paid=349.99,
    currency="USD",
    receipt_image_url="https://example.com/receipt.jpg",
    serial_image_url=None,
    notes="Purchased during holiday sale",
    days_remaining=110,
    status="active",
)


def test_list_warranties_authenticated():
    with (
        patch("app.core.security.decode_supabase_jwt", return_value={"sub": "user-123-uuid"}),
        patch("app.api.v1.warranties.list_warranties", return_value=[MOCK_WARRANTY]),
    ):
        response = client.get(
            "/v1/warranties",
            headers={"Authorization": "Bearer fake.jwt.token"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]["item_name"] == "Sony WH-1000XM5"
        assert data[0]["status"] == "active"


def test_create_warranty_authenticated():
    payload = {
        "item_name": "Sony WH-1000XM5",
        "merchant_name": "Best Buy",
        "category": "Audio",
        "purchase_date": "2026-01-15",
        "warranty_duration_months": 12,
        "price_paid": 349.99,
        "currency": "USD",
        "receipt_image_url": "https://example.com/receipt.jpg",
        "notes": "Purchased during holiday sale",
    }
    with (
        patch("app.core.security.decode_supabase_jwt", return_value={"sub": "user-123-uuid"}),
        patch("app.api.v1.warranties.create_warranty", return_value=MOCK_WARRANTY),
    ):
        response = client.post(
            "/v1/warranties",
            json=payload,
            headers={"Authorization": "Bearer fake.jwt.token"},
        )
        assert response.status_code == 201
        data = response.json()
        assert data["id"] == "e8a15993-21c6-487e-967b-4dca5f917573"
        assert data["item_name"] == "Sony WH-1000XM5"


def test_delete_warranty_authenticated():
    with (
        patch("app.core.security.decode_supabase_jwt", return_value={"sub": "user-123-uuid"}),
        patch("app.api.v1.warranties.delete_warranty", return_value=None),
    ):
        response = client.delete(
            "/v1/warranties/e8a15993-21c6-487e-967b-4dca5f917573",
            headers={"Authorization": "Bearer fake.jwt.token"},
        )
        assert response.status_code == 204
