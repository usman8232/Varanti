from datetime import UTC, date, datetime

from dateutil.relativedelta import relativedelta

from app.models.schemas import WarrantyStatus

DEFAULT_DURATION_MONTHS = 12


def add_calendar_months(start: date, months: int) -> date:
    return start + relativedelta(months=months)


def expiration_date(purchase_date: date, duration_months: int | None) -> date:
    months = duration_months if duration_months and duration_months > 0 else DEFAULT_DURATION_MONTHS
    return add_calendar_months(purchase_date, months)


def days_remaining(expiration: date, *, today: date | None = None) -> int:
    on = today or datetime.now(UTC).date()
    return (expiration - on).days


def warranty_status(remaining_days: int) -> WarrantyStatus:
    if remaining_days > 30:
        return "active"
    if remaining_days >= 1:
        return "expiring_soon"
    return "expired"

