from fastapi import APIRouter

from app.api.v1 import health, ocr, profile, warranties

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(ocr.router, prefix="/v1")
api_router.include_router(profile.router, prefix="/v1")
api_router.include_router(warranties.router, prefix="/v1")
