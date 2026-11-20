from datetime import date

from app.models.schemas import expiration_from, lifecycle_status


def test_expiration_calendar_months() -> None:
    assert expiration_from(date(2026, 1, 31), 1) == date(2026, 2, 28)


def test_lifecycle_badges() -> None:
    today = date(2026, 9, 27)
    assert lifecycle_status(date(2026, 11, 1), today) == (35, "active")
    assert lifecycle_status(date(2026, 10, 12), today) == (15, "expiring_soon")
    assert lifecycle_status(date(2026, 9, 20), today) == (-7, "expired")
