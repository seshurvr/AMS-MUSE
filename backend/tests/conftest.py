"""Shared fixtures for the classroom-attendance API test suite.

Isolation: every run gets a FRESH temp SQLite DB and temp upload dir, wired
through environment variables set BEFORE the app is imported. The developer's
./data/app.db is never touched.

Demo users (teacher@demo.local / Demo1234!, admin@demo.local / Admin1234!) are
seeded directly into the temp DB via the app's own models, so the suite does
not depend on seed.py.
"""
import io
import os
import sys
import tempfile
from pathlib import Path

import pytest

# ---------------------------------------------------------------------------
# Isolated storage. MUST happen before `app.*` is imported, because
# app.config reads these at import time.
# ---------------------------------------------------------------------------
_TMP = Path(tempfile.mkdtemp(prefix="classroom-attendance-test-"))
DATA_DIR = _TMP / "data"
UPLOAD_DIR = _TMP / "uploads"
DATA_DIR.mkdir(parents=True, exist_ok=True)
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
DB_PATH = DATA_DIR / "test.db"

# Direct assignment (not setdefault): tests must win over any ambient env.
os.environ["DATABASE_URL"] = f"sqlite:///{DB_PATH}"
os.environ["JWT_SECRET"] = "test-only-secret-not-for-production"
os.environ["UPLOAD_DIR"] = str(UPLOAD_DIR)
os.environ["ACCESS_TOKEN_EXPIRE_MINUTES"] = "60"
# Rate limiting is exercised by the app, but the suite logs in far more than
# 10x/minute; raise the test limit so it never trips.
os.environ["RATE_LIMIT_LOGIN"] = "10000/minute"

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

from fastapi.testclient import TestClient  # noqa: E402

from app import models  # noqa: E402
from app.database import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.security import hash_password  # noqa: E402

TEACHER_EMAIL = "teacher@demo.local"
TEACHER_PASSWORD = "Demo1234!"
ADMIN_EMAIL = "admin@demo.local"
ADMIN_PASSWORD = "Admin1234!"


def _seed_users() -> None:
    """Create tables and demo accounts in the temp DB (idempotent)."""
    Base.metadata.create_all(engine)
    db = SessionLocal()
    try:
        for username, email, password, role in [
            ("teacher", TEACHER_EMAIL, TEACHER_PASSWORD, "teacher"),
            ("admin", ADMIN_EMAIL, ADMIN_PASSWORD, "admin"),
        ]:
            exists = (
                db.query(models.User).filter(models.User.email == email).first()
            )
            if not exists:
                db.add(
                    models.User(
                        username=username,
                        email=email,
                        password_hash=hash_password(password),
                        role=role,
                    )
                )
        db.commit()
    finally:
        db.close()


def login(client: TestClient, email: str, password: str) -> str:
    """Log in and return the bearer token (asserts success)."""
    r = client.post(
        "/api/auth/login", json={"username": email, "password": password}
    )
    assert r.status_code == 200, f"login failed: {r.status_code} {r.text}"
    body = r.json()
    assert body.get("access_token"), f"no access_token in {body}"
    return body["access_token"]


def make_classroom_png(width: int = 640, height: int = 480,
                       people: int = 3, seed: int = 7) -> bytes:
    """Generate a synthetic classroom-like PNG (crude person silhouettes).

    HOG is not expected to detect these drawings; they exercise the upload
    and processing pipeline end to end.
    """
    try:
        import cv2
        import numpy as np

        rng = np.random.default_rng(seed)
        img = np.full((height, width, 3), 235, dtype=np.uint8)  # bright wall
        img[int(height * 0.7):] = (200, 200, 210)  # floor band
        slots = max(people - 1, 1)
        for i in range(people):
            cx = int(width * (0.15 + 0.7 * i / slots))
            cy = int(height * 0.55)
            cv2.circle(img, (cx, cy - 60), 28, (60, 60, 70), -1)  # head
            cv2.rectangle(  # torso
                img, (cx - 35, cy - 32), (cx + 35, cy + 90),
                (90, 90, 100), -1,
            )
        img = cv2.add(img, rng.integers(0, 12, img.shape, dtype=np.uint8))
        ok, buf = cv2.imencode(".png", img)
        assert ok, "cv2.imencode failed"
        return bytes(buf)
    except ImportError:
        from PIL import Image, ImageDraw  # fallback if cv2 missing

        img = Image.new("RGB", (width, height), (235, 235, 235))
        d = ImageDraw.Draw(img)
        slots = max(people - 1, 1)
        for i in range(people):
            cx = int(width * (0.15 + 0.7 * i / slots))
            cy = int(height * 0.55)
            d.ellipse([cx - 28, cy - 88, cx + 28, cy - 32], fill=(60, 60, 70))
            d.rectangle([cx - 35, cy - 32, cx + 35, cy + 90], fill=(90, 90, 100))
        out = io.BytesIO()
        img.save(out, format="PNG")
        return out.getvalue()


def insert_fake_detection(session_id: int, detection_number: int = 1,
                          x: float = 10.0, y: int = 20,
                          width: float = 60.0, height: float = 120.0,
                          confidence: float = 0.9) -> models.Detection:
    """Insert a Detection row directly (bypasses the CV step for mapping tests)."""
    db = SessionLocal()
    try:
        row = models.Detection(
            session_id=session_id,
            detection_number=detection_number,
            x=x, y=y, width=width, height=height,
            confidence=confidence,
        )
        db.add(row)
        db.commit()
        db.refresh(row)
        # Detach so the caller can use it after the session closes.
        db.expunge(row)
        return row
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
@pytest.fixture(scope="session")
def client() -> TestClient:
    _seed_users()
    with TestClient(app) as c:
        yield c


@pytest.fixture(scope="session")
def teacher_token(client: TestClient) -> str:
    return login(client, TEACHER_EMAIL, TEACHER_PASSWORD)


@pytest.fixture(scope="session")
def admin_token(client: TestClient) -> str:
    return login(client, ADMIN_EMAIL, ADMIN_PASSWORD)


@pytest.fixture()
def teacher_headers(teacher_token: str) -> dict:
    return {"Authorization": f"Bearer {teacher_token}"}


@pytest.fixture()
def admin_headers(admin_token: str) -> dict:
    return {"Authorization": f"Bearer {admin_token}"}


@pytest.fixture()
def png_bytes() -> bytes:
    return make_classroom_png()


def _unique(prefix: str) -> str:
    import uuid

    return f"{prefix}-{uuid.uuid4().hex[:8]}"


@pytest.fixture()
def test_class(client: TestClient, teacher_headers: dict) -> dict:
    """A fresh class per test (avoids cross-test coupling)."""
    r = client.post(
        "/api/classes",
        json={
            "name": _unique("Class"),
            "section": "A",
            "subject": "Mathematics",
            "academic_year": "2026-27",
        },
        headers=teacher_headers,
    )
    assert r.status_code == 201, f"class create failed: {r.status_code} {r.text}"
    return r.json()
