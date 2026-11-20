from datetime import date

from app.models.schemas import WarrantyStatus
from app.services.dates import days_remaining, expiration_date, warranty_status


def test_expiration_adds_calendar_months():
    assert expiration_date(date(2026, 1, 31), 12) == date(2027, 1, 31)
    assert expiration_date(date(2026, 1, 15), None) == date(2027, 1, 15)


def test_status_thresholds():
    today = date(2026, 6, 1)
    remaining_15 = days_remaining(date(2026, 6, 16), today=today)
    assert remaining_15 == 15
    assert warranty_status(remaining_15) == "expiring_soon"
    assert warranty_status(31) == "active"
    assert warranty_status(0) == "expired"
    assert warranty_status(-3) == "expired"

