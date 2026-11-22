from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from app.main import app
from app.models.schemas import ProfileOut

client = TestClient(app)

MOCK_PROFILE = ProfileOut(
    id="user-123-uuid",
    email="usman@example.com",
    full_name="Usman Waseem",
    phone="+923001234567",
    avatar_url="https://example.com/signed-avatar.jpg",
    avatar_path="user-123-uuid/avatar/pic.jpg",
)


def test_profile_requires_authentication():
    resp = client.get("/v1/profile")
    assert resp.status_code == 401


def test_get_profile_authenticated():
    with (
        patch(
            "app.core.security.decode_supabase_jwt",
            return_value={"sub": "user-123-uuid", "email": "usman@example.com"},
        ),
        patch("app.api.v1.profile.get_profile", return_value=MOCK_PROFILE),
    ):
        resp = client.get(
            "/v1/profile",
            headers={"Authorization": "Bearer fake.jwt.token"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["id"] == "user-123-uuid"
        assert data["full_name"] == "Usman Waseem"
        assert data["phone"] == "+923001234567"
        assert data["avatar_url"] == "https://example.com/signed-avatar.jpg"


def test_patch_profile_authenticated():
    with (
        patch(
            "app.core.security.decode_supabase_jwt",
            return_value={"sub": "user-123-uuid", "email": "usman@example.com"},
        ),
        patch("app.api.v1.profile.update_profile", return_value=MOCK_PROFILE),
    ):
        resp = client.patch(
            "/v1/profile",
            json={"full_name": "Usman Waseem", "phone": "+923001234567"},
            headers={"Authorization": "Bearer fake.jwt.token"},
        )
        assert resp.status_code == 200
        assert resp.json()["full_name"] == "Usman Waseem"


def test_upload_avatar_authenticated():
    with (
        patch(
            "app.core.security.decode_supabase_jwt",
            return_value={"sub": "user-123-uuid", "email": "usman@example.com"},
        ),
        patch(
            "app.api.v1.profile.upload_profile_avatar",
            new=AsyncMock(return_value=MOCK_PROFILE),
        ),
    ):
        resp = client.post(
            "/v1/profile/avatar",
            files={"avatar": ("avatar.jpg", b"\xff\xd8\xff\xe0", "image/jpeg")},
            headers={"Authorization": "Bearer fake.jwt.token"},
        )
        assert resp.status_code == 200
        assert resp.json()["avatar_path"] == "user-123-uuid/avatar/pic.jpg"
