"""FastAPI application entry point."""
import os
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from slowapi.util import get_remote_address
from sqlalchemy import text
from sqlalchemy.orm import Session

from app import models  # noqa: F401  (register models before create_all)
from app.api import admin, attendance, auth, classes, export, reports, students
from app.api.deps import get_current_user
from app.config import settings
from app.database import Base, engine, get_db


def _ensure_local_dirs() -> None:
    if settings.DATABASE_URL.startswith("sqlite"):
        # sqlite:///./data/app.db -> ./data ; sqlite:////abs/path.db -> /abs
        raw = settings.DATABASE_URL.split("sqlite:///", 1)[1]
        db_dir = os.path.dirname(os.path.abspath(raw)) if raw.startswith("/") else os.path.dirname(raw)
        if db_dir:
            os.makedirs(db_dir, exist_ok=True)
    os.makedirs(settings.UPLOAD_DIRECTORY, exist_ok=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    _ensure_local_dirs()
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="Classroom Photo Attendance API",
    version="1.0.0",
    description=(
        "Photo-based classroom attendance. Person detection only locates people "
        "(bounding boxes); teachers manually map detections to students."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

limiter = Limiter(key_func=get_remote_address, default_limits=[settings.RATE_LIMIT_DEFAULT])
app.state.limiter = limiter
app.add_middleware(SlowAPIMiddleware)


@app.exception_handler(RateLimitExceeded)
async def _rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return JSONResponse(
        status_code=429,
        content={"detail": "Too many requests. Please slow down and try again."},
    )


@app.get("/api/health")
def health(db: Session = Depends(get_db)):
    db_ok = True
    try:
        db.execute(text("SELECT 1"))
    except Exception:
        db_ok = False
    return {"ok": db_ok, "database": "up" if db_ok else "down"}


@app.get("/api/files/{filename}")
def serve_file(
    filename: str,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return attendance.serve_uploaded_file(filename, user, db)


app.include_router(auth.router)
app.include_router(classes.router)
app.include_router(students.router)
app.include_router(attendance.router)
app.include_router(reports.router)
app.include_router(export.router)
app.include_router(admin.router)
