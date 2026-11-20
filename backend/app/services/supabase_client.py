from supabase import Client, ClientOptions, create_client

from app.core.config import settings
from app.core.security import CurrentUser


def user_client(user: CurrentUser) -> Client:
    if not settings.supabase_url or not settings.supabase_anon_key:
        raise RuntimeError("Supabase URL or anon key is not configured")
    options = ClientOptions(
        headers={
            "Authorization": f"Bearer {user.access_token}",
        }
    )
    client = create_client(settings.supabase_url, settings.supabase_anon_key, options=options)
    client.postgrest.auth(user.access_token)
    return client


_service_client_instance: Client | None = None


def service_client() -> Client:
    global _service_client_instance
    if _service_client_instance is not None:
        return _service_client_instance
    if not settings.supabase_url or not settings.supabase_service_role_key:
        raise RuntimeError("Supabase service role is not configured")
    _service_client_instance = create_client(settings.supabase_url, settings.supabase_service_role_key)
    return _service_client_instance
