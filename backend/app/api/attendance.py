"""Attendance sessions: create, photo upload, detection, review, finalize."""
import mimetypes
import os
import uuid
from datetime import date

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from fastapi.responses import FileResponse
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models, schemas
from app.api.deps import get_current_user, log_action
from app.config import settings
from app.cv import image_quality
from app.database import get_db
from app.services import attendance_service, detection_service

router = APIRouter(prefix="/api/attendance", tags=["attendance"])

ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def _get_session(
    db: Session, session_id: int, user: models.User
) -> models.AttendanceSession:
    session = db.get(models.AttendanceSession, session_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found.")
    if user.role != "admin" and session.created_by != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have access to this session.",
        )
    return session


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


def _image_url(session: models.AttendanceSession) -> str | None:
    if session.image_path:
        return f"/api/files/{session.image_path}"
    return None


@router.post("/sessions", response_model=schemas.SessionOut, status_code=201)
def create_session(
    payload: schemas.SessionCreate,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _check_class_access(db, payload.class_id, user)
    total = (
        db.query(func.count(models.Student.id))
        .filter(
            models.Student.class_id == payload.class_id,
            models.Student.status == "active",
        )
        .scalar()
        or 0
    )
    session = models.AttendanceSession(
        class_id=payload.class_id,
        date=payload.date,
        session_time=payload.session_time,
        subject=payload.subject.strip(),
        notes=payload.notes.strip() if payload.notes else None,
        total_students=total,
        created_by=user.id,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    log_action(db, user, "session_created", "session", session.id)
    return session


@router.post("/sessions/{session_id}/image", response_model=schemas.ImageUploadOut)
async def upload_session_image(
    session_id: int,
    file: UploadFile = File(...),
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = _get_session(db, session_id, user)
    if session.processing_status == "finalized":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session is finalized; the photo cannot be replaced.",
        )

    filename = (file.filename or "").strip()
    ext = os.path.splitext(filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported file type. Please upload a JPG, PNG, or WebP image.",
        )
    if not (file.content_type or "").startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is not an image.",
        )

    content = await file.read()
    if len(content) > settings.MAX_UPLOAD_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Image is too large (max {settings.MAX_UPLOAD_SIZE // 1024 // 1024} MB).",
        )
    if len(content) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )

    os.makedirs(settings.UPLOAD_DIRECTORY, exist_ok=True)
    stored_name = f"{uuid.uuid4().hex}{ext}"
    stored_path = os.path.join(settings.UPLOAD_DIRECTORY, stored_name)
    with open(stored_path, "wb") as f:
        f.write(content)

    try:
        quality = image_quality.analyze(stored_path)
    except ValueError as exc:
        os.remove(stored_path)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Could not read the image: {exc}",
        ) from None

    # Remove any previous photo for this session.
    if session.image_path:
        old = os.path.join(settings.UPLOAD_DIRECTORY, session.image_path)
        if os.path.isfile(old):
            try:
                os.remove(old)
            except OSError:
                pass

    session.image_path = stored_name
    session.image_width = quality["width"]
    session.image_height = quality["height"]
    if session.processing_status == "failed":
        session.processing_status = "uploaded"
        session.processing_error = None
    db.commit()
    log_action(db, user, "session_image_uploaded", "session", session.id)
    return schemas.ImageUploadOut(
        image_url=f"/api/files/{stored_name}",
        quality=schemas.ImageQualityOut(**quality),
    )


@router.post("/sessions/{session_id}/process", response_model=schemas.ProcessOut)
def process_session(
    session_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = _get_session(db, session_id, user)
    if session.processing_status == "finalized":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session is already finalized.",
        )
    if not session.image_path:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No photo uploaded for this session yet.",
        )
    image_path = os.path.join(settings.UPLOAD_DIRECTORY, session.image_path)
    if not os.path.isfile(image_path):
        session.processing_status = "failed"
        session.processing_error = "Image file is missing from storage."
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Image file is missing from storage.",
        )

    session.processing_status = "processing"
    session.processing_error = None
    db.commit()
    try:
        result = detection_service.run_detection(db, session, image_path)
    except Exception as exc:  # never crash the request on CV failure
        db.rollback()
        session = _get_session(db, session_id, user)
        session.processing_status = "failed"
        session.processing_error = str(exc)[:500]
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Person detection failed: {exc}",
        ) from None
    session.processing_status = "processed"
    db.commit()
    log_action(db, user, "session_processed", "session", session.id)
    return schemas.ProcessOut(
        detections=[
            schemas.DetectionOut(**d) for d in result["detections"]
        ],
        count=result["count"],
    )


@router.get("/sessions/{session_id}", response_model=schemas.SessionDetailOut)
def get_session(
    session_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = _get_session(db, session_id, user)
    detections = (
        db.query(models.Detection)
        .filter(models.Detection.session_id == session.id)
        .order_by(models.Detection.detection_number)
        .all()
    )
    records = (
        db.query(models.AttendanceRecord)
        .join(models.Student, models.AttendanceRecord.student_id == models.Student.id)
        .filter(models.AttendanceRecord.session_id == session.id)
        .order_by(models.Student.roll_number, models.Student.name)
        .all()
    )
    return schemas.SessionDetailOut(
        session=schemas.SessionOut.model_validate(session),
        detections=[schemas.DetectionOut.model_validate(d) for d in detections],
        records=[schemas.RecordOut.model_validate(r) for r in records],
        image_url=_image_url(session),
        summary=schemas.SessionSummaryOut(
            **attendance_service.session_summary(db, session)
        ),
    )


@router.put("/sessions/{session_id}/records")
def update_records(
    session_id: int,
    payload: schemas.RecordsUpdateIn,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = _get_session(db, session_id, user)
    if session.processing_status == "finalized":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session is finalized and can no longer be edited.",
        )
    try:
        updated = attendance_service.upsert_records(db, session, payload.records)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
        ) from None
    db.commit()
    log_action(db, user, "session_records_updated", "session", session.id)
    return {"ok": True, "updated": updated}


@router.post("/sessions/{session_id}/finalize")
def finalize_session(
    session_id: int,
    payload: schemas.FinalizeIn,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = _get_session(db, session_id, user)
    if session.processing_status == "finalized":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session is already finalized.",
        )
    if payload.records:
        try:
            attendance_service.upsert_records(db, session, payload.records)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
            ) from None
    summary = attendance_service.finalize_session(db, session)
    db.commit()
    log_action(db, user, "session_finalized", "session", session.id)
    return {"ok": True, "summary": summary}


@router.delete("/sessions/{session_id}")
def delete_session(
    session_id: int,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = _get_session(db, session_id, user)
    if session.image_path:
        path = os.path.join(settings.UPLOAD_DIRECTORY, session.image_path)
        if os.path.isfile(path):
            try:
                os.remove(path)
            except OSError:
                pass
    db.delete(session)
    db.commit()
    log_action(db, user, "session_deleted", "session", session_id)
    return {"ok": True}


@router.get("/history", response_model=list[schemas.HistoryItemOut])
def session_history(
    class_id: int | None = Query(None),
    from_date: date | None = Query(None, alias="from"),
    to_date: date | None = Query(None, alias="to"),
    subject: str | None = Query(None),
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = (
        db.query(models.AttendanceSession, models.ClassRoom)
        .join(models.ClassRoom, models.AttendanceSession.class_id == models.ClassRoom.id)
    )
    if user.role != "admin":
        q = q.filter(models.ClassRoom.teacher_id == user.id)
    if class_id is not None:
        q = q.filter(models.AttendanceSession.class_id == class_id)
    if from_date is not None:
        q = q.filter(models.AttendanceSession.date >= from_date)
    if to_date is not None:
        q = q.filter(models.AttendanceSession.date <= to_date)
    if subject:
        q = q.filter(models.AttendanceSession.subject.ilike(f"%{subject}%"))
    rows = q.order_by(
        models.AttendanceSession.date.desc(),
        models.AttendanceSession.session_time.desc(),
    ).all()

    items = []
    for session, classroom in rows:
        items.append(
            schemas.HistoryItemOut(
                id=session.id,
                date=session.date,
                session_time=session.session_time,
                class_name=classroom.name,
                section=classroom.section,
                subject=session.subject,
                total=session.total_students,
                present=session.present_count,
                absent=session.absent_count,
                excused=session.excused_count,
                needs_review=session.review_count,
                status=session.processing_status,
            )
        )
    return items


def serve_uploaded_file(
    filename: str,
    user: models.User,
    db: Session,
):
    """Serve an uploaded session photo. Auth required; real paths never exposed."""
    safe = os.path.basename(filename)
    if safe != filename or not safe:
        raise HTTPException(status_code=400, detail="Invalid filename.")
    # Never expose real paths; only serve files recorded on sessions the
    # requester may access (own classes for teachers, everything for admins).
    q = (
        db.query(models.AttendanceSession.id)
        .join(
            models.ClassRoom,
            models.AttendanceSession.class_id == models.ClassRoom.id,
        )
        .filter(models.AttendanceSession.image_path == safe)
    )
    if user.role != "admin":
        q = q.filter(models.ClassRoom.teacher_id == user.id)
    if q.first() is None:
        raise HTTPException(status_code=404, detail="File not found.")
    path = os.path.join(settings.UPLOAD_DIRECTORY, safe)
    if not os.path.isfile(path):
        raise HTTPException(status_code=404, detail="File not found.")
    media_type, _ = mimetypes.guess_type(safe)
    return FileResponse(path, media_type=media_type or "application/octet-stream")
