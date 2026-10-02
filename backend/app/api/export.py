"""Attendance export endpoints (CSV / XLSX download)."""
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app import models
from app.api.deps import get_current_user, log_action
from app.database import get_db
from app.services import attendance_service, export_service

router = APIRouter(prefix="/api/export", tags=["export"])


def _get_session(
    db: Session, session_id: int, user: models.User
) -> models.AttendanceSession:
    session = db.get(models.AttendanceSession, session_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Session not found.")
    classroom = db.get(models.ClassRoom, session.class_id)
    if user.role != "admin" and (
        classroom is None or classroom.teacher_id != user.id
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have access to this session.",
        )
    return session


def _export_rows(db: Session, session: models.AttendanceSession) -> list[dict]:
    classroom = db.get(models.ClassRoom, session.class_id)
    records = (
        db.query(models.AttendanceRecord, models.Student)
        .join(models.Student, models.AttendanceRecord.student_id == models.Student.id)
        .filter(models.AttendanceRecord.session_id == session.id)
        .order_by(models.Student.roll_number, models.Student.name)
        .all()
    )
    rows = []
    for record, student in records:
        rows.append(
            {
                "date": session.date,
                "class_name": classroom.name if classroom else "",
                "section": classroom.section if classroom else "",
                "subject": session.subject,
                "student_id": student.student_id,
                "roll_number": student.roll_number,
                "name": student.name,
                "status": record.status,
                "manually_confirmed": record.manually_confirmed,
            }
        )
    return rows


@router.get("/attendance")
def export_attendance(
    session_id: int | None = Query(None),
    format: str = Query("csv", pattern="^(csv|xlsx)$"),
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if session_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Query parameter 'session_id' is required.",
        )
    session = _get_session(db, session_id, user)
    classroom = db.get(models.ClassRoom, session.class_id)
    rows = _export_rows(db, session)
    summary = attendance_service.session_summary(db, session)
    log_action(db, user, "attendance_exported", "session", session.id)

    base = f"attendance_{session.date.isoformat()}_{session.subject}".replace(" ", "_")
    if format == "csv":
        content = export_service.build_attendance_csv(rows)
        return Response(
            content=content,
            media_type="text/csv",
            headers={"Content-Disposition": f'attachment; filename="{base}.csv"'},
        )
    meta = {
        "class_name": classroom.name if classroom else "",
        "section": classroom.section if classroom else "",
        "subject": session.subject,
        "date": session.date,
        "session_time": session.session_time,
    }
    content = export_service.build_attendance_xlsx(meta, rows, summary)
    return Response(
        content=content,
        media_type=(
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        ),
        headers={"Content-Disposition": f'attachment; filename="{base}.xlsx"'},
    )
