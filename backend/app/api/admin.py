"""Admin-only endpoints: user management and audit logs."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app import models, schemas
from app.api.deps import log_action, require_admin
from app.database import get_db
from app.security import hash_password

router = APIRouter(prefix="/api/admin", tags=["admin"])


@router.get("/users", response_model=list[schemas.UserOut])
def list_users(
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    return db.query(models.User).order_by(models.User.username).all()


@router.post("/users", response_model=schemas.UserOut, status_code=201)
def create_user(
    payload: schemas.AdminUserCreate,
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    username = payload.username.strip()
    email = payload.email.strip().lower()
    if db.query(models.User).filter(models.User.username == username).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Username '{username}' is already taken.",
        )
    if db.query(models.User).filter(models.User.email == email).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Email '{email}' is already registered.",
        )
    user = models.User(
        username=username,
        email=email,
        password_hash=hash_password(payload.password),
        role=payload.role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    log_action(db, admin, "user_created", "user", user.id)
    return user


@router.get("/audit-logs", response_model=list[schemas.AuditLogOut])
def list_audit_logs(
    limit: int = Query(200, ge=1, le=1000),
    admin: models.User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(models.AuditLog, models.User.username)
        .outerjoin(models.User, models.AuditLog.user_id == models.User.id)
        .order_by(models.AuditLog.timestamp.desc())
        .limit(limit)
        .all()
    )
    return [
        schemas.AuditLogOut(
            id=log.id,
            user_id=log.user_id,
            username=username,
            action=log.action,
            record_type=log.record_type,
            record_id=log.record_id,
            timestamp=log.timestamp,
        )
        for log, username in rows
    ]
