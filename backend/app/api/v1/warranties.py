from typing import Annotated

from fastapi import APIRouter, Depends, File, Query, Response, UploadFile, status

from app.core.security import CurrentUser, get_current_user
from app.models.schemas import ImageUrls, WarrantyCreate, WarrantyOut, WarrantyUpdate
from app.services.ocr.pipeline import upload_warranty_images
from app.services.warranties import (
    create_warranty,
    delete_warranty,
    get_warranty,
    list_warranties,
    update_warranty,
)

router = APIRouter(prefix="/warranties", tags=["warranties"])


@router.post("/upload-images", response_model=ImageUrls, status_code=status.HTTP_201_CREATED)
async def upload_images(
    receipt: Annotated[UploadFile, File()],
    user: Annotated[CurrentUser, Depends(get_current_user)],
    serial: Annotated[UploadFile | None, File()] = None,
) -> ImageUrls:
    return await upload_warranty_images(user, receipt, serial)


@router.get("", response_model=list[WarrantyOut])
def list_items(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    q: Annotated[str | None, Query()] = None,
    category: Annotated[str | None, Query()] = None,
) -> list[WarrantyOut]:
    return list_warranties(user, q, category)


@router.post("", response_model=WarrantyOut, status_code=status.HTTP_201_CREATED)
def create_item(
    body: WarrantyCreate,
    user: Annotated[CurrentUser, Depends(get_current_user)],
) -> WarrantyOut:
    return create_warranty(user, body)


@router.get("/{warranty_id}", response_model=WarrantyOut)
def get_item(
    warranty_id: str,
    user: Annotated[CurrentUser, Depends(get_current_user)],
) -> WarrantyOut:
    return get_warranty(user, warranty_id)


@router.patch("/{warranty_id}", response_model=WarrantyOut)
def patch_item(
    warranty_id: str,
    body: WarrantyUpdate,
    user: Annotated[CurrentUser, Depends(get_current_user)],
) -> WarrantyOut:
    return update_warranty(user, warranty_id, body)


@router.delete("/{warranty_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_item(
    warranty_id: str,
    user: Annotated[CurrentUser, Depends(get_current_user)],
) -> Response:
    delete_warranty(user, warranty_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
