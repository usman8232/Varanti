from unittest.mock import patch
import jwt
import pytest
from fastapi import HTTPException

from app.core.security import decode_supabase_jwt


def test_decode_supabase_jwt_valid():
    secret = "test-super-secret-key-for-supabase-jwt"
    token = jwt.encode(
        {"sub": "user-123-uuid", "email": "test@example.com", "aud": "authenticated"},
        secret,
        algorithm="HS256",
    )
    with patch("app.core.security.settings.supabase_jwt_secret", secret):
        payload = decode_supabase_jwt(token)
        assert payload["sub"] == "user-123-uuid"
        assert payload["email"] == "test@example.com"


def test_decode_supabase_jwt_invalid():
    secret = "test-super-secret-key-for-supabase-jwt"
    with patch("app.core.security.settings.supabase_jwt_secret", secret):
        with pytest.raises(HTTPException) as exc_info:
            decode_supabase_jwt("invalid.token.payload")
        assert exc_info.value.status_code == 401


def test_decode_supabase_jwt_unconfigured():
    with patch("app.core.security.settings.supabase_jwt_secret", ""):
        with pytest.raises(HTTPException) as exc_info:
            decode_supabase_jwt("some-token")
        assert exc_info.value.status_code == 503


@pytest.mark.anyio
async def test_get_current_user_valid():
    from app.core.security import get_current_user
    from fastapi.security import HTTPAuthorizationCredentials

    secret = "test-super-secret-key-for-supabase-jwt"
    token = jwt.encode(
        {"sub": "user-456-uuid", "email": "test456@example.com", "aud": "authenticated"},
        secret,
        algorithm="HS256",
    )
    with patch("app.core.security.settings.supabase_jwt_secret", secret):
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        user = await get_current_user(creds)
        assert user.id == "user-456-uuid"
        assert user.email == "test456@example.com"
        assert user.access_token == token


@pytest.mark.anyio
async def test_get_current_user_missing_creds():
    from app.core.security import get_current_user

    with pytest.raises(HTTPException) as exc_info:
        await get_current_user(None)
    assert exc_info.value.status_code == 401
    assert "Missing bearer token" in exc_info.value.detail


@pytest.mark.anyio
async def test_get_current_user_missing_sub():
    from app.core.security import get_current_user
    from fastapi.security import HTTPAuthorizationCredentials

    secret = "test-super-secret-key-for-supabase-jwt"
    token = jwt.encode(
        {"email": "nosub@example.com", "aud": "authenticated"},
        secret,
        algorithm="HS256",
    )
    with patch("app.core.security.settings.supabase_jwt_secret", secret):
        creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(creds)
        assert exc_info.value.status_code == 401
        assert "Token missing subject" in exc_info.value.detail


def test_api_routes_require_authentication():
    from fastapi.testclient import TestClient
    from app.main import app

    client = TestClient(app)

    # Health is public
    res = client.get("/health")
    assert res.status_code == 200

    # Protected routes return 401 without bearer token
    res = client.get("/v1/warranties")
    assert res.status_code == 401
    assert res.json()["detail"] == "Missing bearer token"

    res = client.post("/v1/warranties", json={"item_name": "Test"})
    assert res.status_code == 401

    res = client.get("/v1/warranties/some-id")
    assert res.status_code == 401

    res = client.post("/v1/ocr/scan", files={"receipt": ("test.jpg", b"fake", "image/jpeg")})
    assert res.status_code == 401


def test_ocr_rate_key_distinguishes_users():
    from starlette.requests import Request
    from app.core.rate_limit import ocr_rate_key

    secret = "test-super-secret-key-for-supabase-jwt"
    tok_a = jwt.encode({"sub": "user-a", "aud": "authenticated"}, secret, algorithm="HS256")
    tok_b = jwt.encode({"sub": "user-b", "aud": "authenticated"}, secret, algorithm="HS256")

    def make_request(token: str) -> Request:
        scope = {
            "type": "http",
            "method": "POST",
            "path": "/v1/ocr/scan",
            "headers": [(b"authorization", f"Bearer {token}".encode())],
            "client": ("127.0.0.1", 12345),
        }
        return Request(scope)

    key_a = ocr_rate_key(make_request(tok_a))
    key_b = ocr_rate_key(make_request(tok_b))
    assert key_a != key_b
    assert "user-a" in key_a
    assert "user-b" in key_b

