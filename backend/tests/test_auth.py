"""Auth: login, /me, 401 handling, password change."""
from fastapi.testclient import TestClient

from .conftest import (
    ADMIN_EMAIL,
    ADMIN_PASSWORD,
    TEACHER_EMAIL,
    TEACHER_PASSWORD,
    login,
)

NEW_PASSWORD = "NewPass123!"


def test_login_ok(client: TestClient):
    r = client.post(
        "/api/auth/login",
        json={"username": TEACHER_EMAIL, "password": TEACHER_PASSWORD},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["access_token"]
    assert body["token_type"] == "bearer"
    assert body["user"]["email"] == TEACHER_EMAIL
    assert body["user"]["role"] == "teacher"


def test_login_by_username_ok(client: TestClient):
    # LoginIn accepts username OR email.
    r = client.post(
        "/api/auth/login", json={"username": "teacher", "password": TEACHER_PASSWORD}
    )
    assert r.status_code == 200, r.text


def test_login_bad_password(client: TestClient):
    r = client.post(
        "/api/auth/login",
        json={"username": TEACHER_EMAIL, "password": "wrong-password"},
    )
    assert r.status_code == 401


def test_login_unknown_user(client: TestClient):
    r = client.post(
        "/api/auth/login",
        json={"username": "nobody@example.local", "password": "whatever123"},
    )
    assert r.status_code == 401


def test_me_ok(client: TestClient, teacher_headers: dict):
    r = client.get("/api/auth/me", headers=teacher_headers)
    assert r.status_code == 200, r.text
    assert r.json()["email"] == TEACHER_EMAIL


def test_me_no_token_401(client: TestClient):
    r = client.get("/api/auth/me")
    assert r.status_code == 401


def test_me_bad_token_401(client: TestClient):
    r = client.get("/api/auth/me", headers={"Authorization": "Bearer junk"})
    assert r.status_code == 401


def test_admin_login_ok(client: TestClient):
    token = login(client, ADMIN_EMAIL, ADMIN_PASSWORD)
    r = client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert r.json()["role"] == "admin"


def test_password_change(client: TestClient, teacher_headers: dict):
    # Change to a new password...
    r = client.put(
        "/api/auth/password",
        json={"current_password": TEACHER_PASSWORD, "new_password": NEW_PASSWORD},
        headers=teacher_headers,
    )
    assert r.status_code == 200, r.text
    assert r.json().get("ok") is True

    # ...new password works...
    token = login(client, TEACHER_EMAIL, NEW_PASSWORD)
    assert token

    # ...old password no longer works...
    r = client.post(
        "/api/auth/login",
        json={"username": TEACHER_EMAIL, "password": TEACHER_PASSWORD},
    )
    assert r.status_code == 401

    # ...restore the original password so other tests keep working.
    r = client.put(
        "/api/auth/password",
        json={"current_password": NEW_PASSWORD, "new_password": TEACHER_PASSWORD},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 200, r.text
    login(client, TEACHER_EMAIL, TEACHER_PASSWORD)  # restored


def test_password_change_wrong_current(client: TestClient, teacher_headers: dict):
    r = client.put(
        "/api/auth/password",
        json={"current_password": "not-the-password", "new_password": NEW_PASSWORD},
        headers=teacher_headers,
    )
    assert r.status_code == 400


def test_rate_limit_exceeded_returns_429_json():
    """slowapi is wired: a 1/minute probe route must 429 on the second hit."""
    from fastapi import Request
    from fastapi.testclient import TestClient
    from slowapi import Limiter
    from slowapi.util import get_remote_address

    from app.main import app

    probe_limiter = Limiter(key_func=get_remote_address)

    @app.get("/api/_probe_rate_limit_test_only")
    @probe_limiter.limit("1/minute")
    def _probe(request: Request):  # pragma: no cover - test probe
        return {"ok": True}

    probe_client = TestClient(app, raise_server_exceptions=False)
    assert probe_client.get("/api/_probe_rate_limit_test_only").status_code == 200
    r = probe_client.get("/api/_probe_rate_limit_test_only")
    assert r.status_code == 429, r.text
    assert "Too many requests" in r.json()["detail"]
