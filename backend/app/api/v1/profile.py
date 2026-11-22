from typing import Annotated

from fastapi import APIRouter, Depends, File, UploadFile

from app.core.security import CurrentUser, get_current_user
from app.models.schemas import ProfileOut, ProfileUpdate
from app.services.profile import get_profile, update_profile, upload_profile_avatar

router = APIRouter(prefix="/profile", tags=["profile"])


@router.get("", response_model=ProfileOut)
def read_profile(
    user: Annotated[CurrentUser, Depends(get_current_user)],
) -> ProfileOut:
    return get_profile(user)


@router.patch("", response_model=ProfileOut)
def patch_profile(
    body: ProfileUpdate,
    user: Annotated[CurrentUser, Depends(get_current_user)],
) -> ProfileOut:
    return update_profile(user, body)


@router.post("/avatar", response_model=ProfileOut)
async def upload_avatar(
    avatar: Annotated[UploadFile, File()],
    user: Annotated[CurrentUser, Depends(get_current_user)],
) -> ProfileOut:
    return await upload_profile_avatar(user, avatar)
