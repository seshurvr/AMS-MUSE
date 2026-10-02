"""Student CRUD."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import models, schemas
from app.api.deps import get_current_user, log_action
from app.database import get_db

router = APIRouter(prefix="/api/students", tags=["students"])


def _check_class_access(
    db: Session, class_id: int, user: models.User
) -> models.ClassRoom:
    classroom = db.get(models.ClassRoom, class_id)
    if classroom is None:
        raise HTTPException(status_code=404, detail="Class not found.")
    if user.role != "admin" and classroom.teacher_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have access to this class.",
        )
    return classroom


def _get_student(db: Session, student_id: int, user: models.User) -> models.Student:
    student = db.get(models.Student, student_id)
    if student is None:
        raise HTTPException(status_code=404, detail="Student not found.")
    _check_class_access(db, student.class_id, user)
    return student


def _ensure_unique(
    db: Session,
    class_id: int,
    student_id: str | None,
    roll_number: str | None,
    exclude_id: int | None = None,
) -> None:
    q = db.query(models.Student).filter(
        models.Student.class_id == class_id,
        models.Student.status == "active",
    )
    if exclude_id is not None:
        q = q.filter(models.Student.id != exclude_id)
    if student_id is not None:
        clash = q.filter(models.Student.student_id == student_id).first()
        if clash:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Student ID '{student_id}' already exists in this class.",
            )
    if roll_number is not None:
        clash = q.filter(models.Student.roll_number == roll_number).first()
        if clash:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Roll number '{roll_number}' already exists in this class.",
            )


@router.post("", response_model=schemas.StudentOut, status_code=201)
def create_student(
    payload: schemas.StudentCreate,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _check_class_access(db, payload.class_id, user)
    _ensure_unique(
        db, payload.class_id, payload.student_id.strip(), payload.roll_number.strip()
    )
    student = models.Student(
        class_id=payload.class_id,
        student_id=payload.student_id.strip(),
        roll_number=payload.roll_number.strip(),
        name=payload.name.strip(),
        email=payload.email,
    )
    db.add(student)
    db.commit()
    db.refresh(student)
    log_action(db, user, "student_created", "student", student.id)
    return student


@router.get("/{student_id}", response_model=schemas.StudentOut)
def get_student(
    student_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _get_student(db, student_id, user)


@router.put("/{student_id}", response_model=schemas.StudentOut)
def update_student(
    student_id: int,
    payload: schemas.StudentUpdate,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    student = _get_student(db, student_id, user)
    new_sid = payload.student_id.strip() if payload.student_id else None
    new_roll = payload.roll_number.strip() if payload.roll_number else None
    _ensure_unique(db, student.class_id, new_sid, new_roll, exclude_id=student.id)
    if new_sid is not None:
        student.student_id = new_sid
    if new_roll is not None:
        student.roll_number = new_roll
    if payload.name is not None:
        student.name = payload.name.strip()
    if payload.email is not None:
        student.email = payload.email
    db.commit()
    db.refresh(student)
    log_action(db, user, "student_updated", "student", student.id)
    return student


@router.delete("/{student_id}")
def archive_student(
    student_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    student = _get_student(db, student_id, user)
    student.status = "archived"
    db.commit()
    log_action(db, user, "student_archived", "student", student.id)
    return {"ok": True}
