"""Class CRUD plus student CSV import/export for a class."""
import csv
import io

from fastapi import APIRouter, Depends, HTTPException, Query, Response, UploadFile, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models, schemas
from app.api.deps import get_current_user, log_action
from app.database import get_db

router = APIRouter(prefix="/api/classes", tags=["classes"])


def _get_class(
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


def _student_counts(db: Session) -> dict[int, int]:
    rows = (
        db.query(models.Student.class_id, func.count(models.Student.id))
        .filter(models.Student.status == "active")
        .group_by(models.Student.class_id)
        .all()
    )
    return {class_id: count for class_id, count in rows}


def _class_out(classroom: models.ClassRoom, counts: dict[int, int]) -> schemas.ClassOut:
    return schemas.ClassOut(
        id=classroom.id,
        name=classroom.name,
        section=classroom.section,
        subject=classroom.subject,
        academic_year=classroom.academic_year,
        teacher_id=classroom.teacher_id,
        status=classroom.status,
        student_count=counts.get(classroom.id, 0),
        created_at=classroom.created_at,
        updated_at=classroom.updated_at,
    )


@router.get("", response_model=list[schemas.ClassOut])
def list_classes(
    status: str = Query("active", pattern="^(active|archived|all)$"),
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = db.query(models.ClassRoom)
    if user.role != "admin":
        q = q.filter(models.ClassRoom.teacher_id == user.id)
    if status != "all":
        q = q.filter(models.ClassRoom.status == status)
    classrooms = q.order_by(models.ClassRoom.name, models.ClassRoom.section).all()
    counts = _student_counts(db)
    return [_class_out(c, counts) for c in classrooms]


@router.post("", response_model=schemas.ClassOut, status_code=201)
def create_class(
    payload: schemas.ClassCreate,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    classroom = models.ClassRoom(
        name=payload.name.strip(),
        section=payload.section.strip(),
        subject=payload.subject.strip(),
        academic_year=payload.academic_year.strip(),
        teacher_id=user.id,
    )
    db.add(classroom)
    db.commit()
    db.refresh(classroom)
    log_action(db, user, "class_created", "class", classroom.id)
    return _class_out(classroom, _student_counts(db))


@router.get("/{class_id}", response_model=schemas.ClassDetailOut)
def get_class(
    class_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    classroom = _get_class(db, class_id, user)
    students = (
        db.query(models.Student)
        .filter(
            models.Student.class_id == class_id,
            models.Student.status == "active",
        )
        .order_by(models.Student.roll_number, models.Student.name)
        .all()
    )
    out = _class_out(classroom, _student_counts(db))
    detail = schemas.ClassDetailOut(**out.model_dump())
    detail.students = [schemas.StudentOut.model_validate(s) for s in students]
    return detail


@router.put("/{class_id}", response_model=schemas.ClassOut)
def update_class(
    class_id: int,
    payload: schemas.ClassUpdate,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    classroom = _get_class(db, class_id, user)
    for field in ("name", "section", "subject", "academic_year"):
        value = getattr(payload, field)
        if value is not None:
            setattr(classroom, field, value.strip())
    db.commit()
    db.refresh(classroom)
    log_action(db, user, "class_updated", "class", classroom.id)
    return _class_out(classroom, _student_counts(db))


@router.delete("/{class_id}")
def archive_class(
    class_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    classroom = _get_class(db, class_id, user)
    classroom.status = "archived"
    db.commit()
    log_action(db, user, "class_archived", "class", classroom.id)
    return {"ok": True}


@router.get("/{class_id}/students", response_model=list[schemas.StudentOut])
def list_class_students(
    class_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _get_class(db, class_id, user)
    return (
        db.query(models.Student)
        .filter(
            models.Student.class_id == class_id,
            models.Student.status == "active",
        )
        .order_by(models.Student.roll_number, models.Student.name)
        .all()
    )


@router.post("/{class_id}/students/import", response_model=schemas.CsvImportResult)
async def import_students_csv(
    class_id: int,
    file: UploadFile,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _get_class(db, class_id, user)
    if not (file.filename or "").lower().endswith(".csv"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Please upload a .csv file.",
        )
    content = await file.read()
    try:
        text = content.decode("utf-8-sig")
    except UnicodeDecodeError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="CSV must be UTF-8 encoded.",
        ) from None
    reader = csv.DictReader(io.StringIO(text))
    required = {"student_id", "roll_number", "name"}
    if reader.fieldnames is None or not required.issubset(
        {h.strip() for h in reader.fieldnames}
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="CSV must have headers: student_id, roll_number, name.",
        )

    existing_ids = {
        r[0]
        for r in db.query(models.Student.student_id).filter(
            models.Student.class_id == class_id,
            models.Student.status == "active",
        )
    }
    existing_rolls = {
        r[0]
        for r in db.query(models.Student.roll_number).filter(
            models.Student.class_id == class_id,
            models.Student.status == "active",
        )
    }
    seen_ids: set[str] = set()
    seen_rolls: set[str] = set()
    imported = 0
    skipped = 0
    errors: list[schemas.CsvImportError] = []

    for lineno, row in enumerate(reader, start=2):
        sid = (row.get("student_id") or "").strip()
        roll = (row.get("roll_number") or "").strip()
        name = (row.get("name") or "").strip()
        if not sid or not roll or not name:
            errors.append(
                schemas.CsvImportError(
                    row=lineno, message="Missing student_id, roll_number, or name."
                )
            )
            continue
        if sid in existing_ids or sid in seen_ids:
            skipped += 1
            continue
        if roll in existing_rolls or roll in seen_rolls:
            skipped += 1
            continue
        db.add(
            models.Student(
                class_id=class_id, student_id=sid, roll_number=roll, name=name
            )
        )
        seen_ids.add(sid)
        seen_rolls.add(roll)
        imported += 1

    db.commit()
    log_action(db, user, "students_imported", "class", class_id)
    return schemas.CsvImportResult(
        imported=imported, skipped=skipped, errors=errors
    )


@router.get("/{class_id}/students/export")
def export_students_csv(
    class_id: int,
    format: str = Query("csv", pattern="^(csv)$"),
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    classroom = _get_class(db, class_id, user)
    students = (
        db.query(models.Student)
        .filter(
            models.Student.class_id == class_id,
            models.Student.status == "active",
        )
        .order_by(models.Student.roll_number, models.Student.name)
        .all()
    )
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(["student_id", "roll_number", "name", "email", "status"])
    for s in students:
        writer.writerow([s.student_id, s.roll_number, s.name, s.email or "", s.status])
    log_action(db, user, "students_exported", "class", classroom.id)
    filename = f"students_{classroom.name}_{classroom.section}.csv".replace(" ", "_")
    return Response(
        content=buf.getvalue(),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
