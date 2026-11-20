from datetime import UTC, date, datetime
from typing import Literal

from dateutil.relativedelta import relativedelta
from pydantic import AliasChoices, BaseModel, Field, computed_field

WarrantyCategory = Literal[
    "Consumer Tech",
    "Home Appliances",
    "Computing",
    "Audio",
    "Power Tools",
    "Other",
]

WarrantyStatus = Literal["active", "expiring_soon", "expired"]


class ExtractedFields(BaseModel):
    merchant_name: str | None = None
    purchase_date: date | None = None
    item_name: str = ""
    serial_number: str | None = None
    warranty_duration_months: int = Field(default=12, ge=1, le=600)
    total_amount: float | None = None
    currency: str = Field(default="USD", min_length=3, max_length=3)


class ImageUrls(BaseModel):
    receipt_url: str = Field(validation_alias=AliasChoices("receipt_url", "receipt_image_url"))
    receipt_path: str
    serial_url: str | None = Field(default=None, validation_alias=AliasChoices("serial_url", "serial_image_url"))
    serial_path: str | None = None

    @computed_field
    @property
    def receipt_image_url(self) -> str:
        return self.receipt_url

    @computed_field
    @property
    def serial_image_url(self) -> str | None:
        return self.serial_url


ImageRefs = ImageUrls



class OcrScanResponse(BaseModel):
    images: ImageUrls
    raw_text: str
    extracted: ExtractedFields
    warranty_expiration_date: date | None = None
    ocr_failed: bool = False
    needs_review: bool = False


class WarrantyCreate(BaseModel):
    item_name: str
    merchant_name: str | None = None
    category: WarrantyCategory = "Consumer Tech"
    purchase_date: date
    warranty_duration_months: int = Field(default=12, ge=1, le=600)
    warranty_expiration_date: date | None = None
    serial_number: str | None = None
    price_paid: float | None = None
    currency: str = Field(default="USD", min_length=3, max_length=3)
    receipt_image_url: str
    receipt_image_path: str | None = None
    serial_image_url: str | None = None
    serial_image_path: str | None = None
    notes: str | None = None


class WarrantyUpdate(BaseModel):
    item_name: str | None = None
    merchant_name: str | None = None
    category: WarrantyCategory | None = None
    purchase_date: date | None = None
    warranty_duration_months: int | None = Field(default=None, ge=1, le=600)
    warranty_expiration_date: date | None = None
    serial_number: str | None = None
    price_paid: float | None = None
    currency: str | None = Field(default=None, min_length=3, max_length=3)
    notes: str | None = None


class WarrantyOut(BaseModel):
    id: str
    user_id: str
    item_name: str
    merchant_name: str | None = None
    category: str
    purchase_date: date
    warranty_duration_months: int
    warranty_expiration_date: date
    serial_number: str | None = None
    price_paid: float | None = None
    currency: str | None = None
    receipt_image_url: str
    receipt_image_path: str | None = None
    serial_image_url: str | None = None
    serial_image_path: str | None = None
    notes: str | None = None
    days_remaining: int
    status: WarrantyStatus


class DiscardUploadsRequest(BaseModel):
    receipt_path: str | None = None
    serial_path: str | None = None


def expiration_from(purchase: date, months: int) -> date:
    return purchase + relativedelta(months=months)


def lifecycle_status(expiration: date, today: date | None = None) -> tuple[int, WarrantyStatus]:
    today = today or datetime.now(UTC).date()
    days = (expiration - today).days
    if days > 30:
        return days, "active"
    if days >= 1:
        return days, "expiring_soon"
    return days, "expired"
