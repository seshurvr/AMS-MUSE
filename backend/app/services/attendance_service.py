"""Attendance record helpers: upsert, backfill, finalize, summaries."""
from sqlalchemy.orm import Session

from app import models, schemas


def _student_ids_in_class(db: Session, class_id: int) -> set[int]:
    rows = (
        db.query(models.Student.id)
        .filter(
            models.Student.class_id == class_id,
            models.Student.status == "active",
        )
        .all()
    )
    return {r[0] for r in rows}


def upsert_records(
    db: Session,
    session: models.AttendanceSession,
    records_in: list[schemas.RecordIn],
) -> int:
    """Create or update draft records for a session. Returns number upserted."""
    valid_student_ids = _student_ids_in_class(db, session.class_id)
    detection_ids = {
        d.id for d in db.query(models.Detection.id).filter(
            models.Detection.session_id == session.id
        )
    }

    count = 0
    for item in records_in:
        if item.student_id not in valid_student_ids:
            raise ValueError(
                f"Student {item.student_id} does not belong to this class."
            )
        if item.detection_id is not None and item.detection_id not in detection_ids:
            raise ValueError(
                f"Detection {item.detection_id} does not belong to this session."
            )
        existing = (
            db.query(models.AttendanceRecord)
            .filter(
                models.AttendanceRecord.session_id == session.id,
                models.AttendanceRecord.student_id == item.student_id,
            )
            .one_or_none()
        )
        if existing is None:
            db.add(
                models.AttendanceRecord(
                    session_id=session.id,
                    student_id=item.student_id,
                    status=item.status,
                    detection_id=item.detection_id,
                    manually_confirmed=item.manually_confirmed,
                    notes=item.notes,
                )
            )
        else:
            existing.status = item.status
            existing.detection_id = item.detection_id
            existing.manually_confirmed = item.manually_confirmed
            existing.notes = item.notes
        count += 1
    db.flush()
    return count


def ensure_records_for_all_students(
    db: Session, session: models.AttendanceSession
) -> None:
    """Backfill missing students as needs_review.

    Never auto-marks anyone absent: students the camera did not detect (or the
    teacher did not map) default to needs_review so the teacher confirms
    everything manually.
    """
    student_ids = _student_ids_in_class(db, session.class_id)
    existing_ids = {
        r[0]
        for r in db.query(models.AttendanceRecord.student_id).filter(
            models.AttendanceRecord.session_id == session.id
        )
    }
    for sid in sorted(student_ids - existing_ids):
        db.add(
            models.AttendanceRecord(
                session_id=session.id,
                student_id=sid,
                status="needs_review",
                manually_confirmed=False,
            )
        )
    db.flush()


def session_summary(
    db: Session, session: models.AttendanceSession
) -> dict:
    """Live summary computed from current records."""
    records = (
        db.query(models.AttendanceRecord)
        .filter(models.AttendanceRecord.session_id == session.id)
        .all()
    )
    counts = {"present": 0, "absent": 0, "excused": 0, "needs_review": 0}
    for r in records:
        if r.status in counts:
            counts[r.status] += 1
    total = session.total_students
    pct = round(counts["present"] / total * 100, 1) if total else 0.0
    return {
        "total": total,
        "detected": session.detected_count,
        "present": counts["present"],
        "absent": counts["absent"],
        "excused": counts["excused"],
        "needs_review": counts["needs_review"],
        "attendance_percentage": pct,
    }


def finalize_session(db: Session, session: models.AttendanceSession) -> dict:
    """Finalize: backfill missing records, store counts, mark finalized."""
    ensure_records_for_all_students(db, session)
    summary = session_summary(db, session)
    session.present_count = summary["present"]
    session.absent_count = summary["absent"]
    session.excused_count = summary["excused"]
    session.review_count = summary["needs_review"]
    session.processing_status = "finalized"
    session.processing_error = None
    db.flush()
    return summary
