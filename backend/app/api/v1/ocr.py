import asyncio
from typing import Annotated

from fastapi import APIRouter, Depends, File, Request, Response, UploadFile, status

from app.core.config import settings
from app.core.rate_limit import limiter, ocr_limit_string
from app.core.security import CurrentUser, get_current_user
from app.models.schemas import DiscardUploadsRequest, OcrScanResponse
from app.services.ocr.pipeline import run_scan
from app.services.storage import remove_objects

router = APIRouter(prefix="/ocr", tags=["ocr"])


@router.post("/scan", response_model=OcrScanResponse)
@limiter.limit(ocr_limit_string())
async def scan_receipt(
    request: Request,
    receipt: Annotated[UploadFile, File()],
    user: Annotated[CurrentUser, Depends(get_current_user)],
    serial: Annotated[UploadFile | None, File()] = None,
) -> OcrScanResponse:
    return await run_scan(user, receipt, serial)


@router.post("/discard", status_code=status.HTTP_204_NO_CONTENT)
async def discard_uploads(
    body: DiscardUploadsRequest,
    user: Annotated[CurrentUser, Depends(get_current_user)],
) -> Response:
    if body.receipt_path:
        await asyncio.to_thread(
            remove_objects,
            user,
            settings.supabase_receipts_bucket,
            [body.receipt_path],
        )
    if body.serial_path:
        await asyncio.to_thread(
            remove_objects,
            user,
            settings.supabase_serials_bucket,
            [body.serial_path],
        )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
