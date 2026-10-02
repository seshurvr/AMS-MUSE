"""Authentication endpoints."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app import models, schemas
from app.api.deps import get_current_user, log_action
from app.database import get_db
from app.security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/login", response_model=schemas.LoginOut)
def login(payload: schemas.LoginIn, db: Session = Depends(get_db)):
    identifier = payload.username.strip()
    user = (
        db.query(models.User)
        .filter(
            or_(
                models.User.username == identifier,
                func.lower(models.User.email) == identifier.lower(),
            )
        )
        .one_or_none()
    )
    if user is None or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password.",
        )
    log_action(db, user, "login")
    return {
        "access_token": create_access_token(str(user.id)),
        "token_type": "bearer",
        "user": user,
    }


@router.post("/logout")
def logout():
    # JWTs are stateless; the client discards the token. Audit entry for the
    # explicit logout action is optional, so we simply acknowledge.
    return {"ok": True}


@router.get("/me", response_model=schemas.UserOut)
def me(user: models.User = Depends(get_current_user)):
    return user


@router.put("/password")
def change_password(
    payload: schemas.PasswordChangeIn,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect.",
        )
    user.password_hash = hash_password(payload.new_password)
    db.commit()
    log_action(db, user, "password_changed")
    return {"ok": True}
