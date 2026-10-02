"""Aggregated attendance reports."""
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app import models, schemas
from app.api.deps import get_current_user
from app.database import get_db

router = APIRouter(prefix="/api/reports", tags=["reports"])


@router.get("/summary", response_model=schemas.ReportSummaryOut)
def report_summary(
    class_id: int | None = Query(None),
    from_date: date | None = Query(None, alias="from"),
    to_date: date | None = Query(None, alias="to"),
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = db.query(models.ClassRoom)
    if user.role != "admin":
        q = q.filter(models.ClassRoom.teacher_id == user.id)
    if class_id is not None:
        q = q.filter(models.ClassRoom.id == class_id)
    classrooms = q.filter(models.ClassRoom.status == "active").all()
    if class_id is not None and not classrooms:
        raise HTTPException(status_code=404, detail="Class not found.")

    students_out: list[schemas.ReportStudentOut] = []
    total_sessions_all = 0
    pct_sum = 0.0
    total_students_all = 0

    for classroom in classrooms:
        sq = (
            db.query(models.AttendanceSession)
            .filter(
                models.AttendanceSession.class_id == classroom.id,
                models.AttendanceSession.processing_status == "finalized",
            )
        )
        if from_date is not None:
            sq = sq.filter(models.AttendanceSession.date >= from_date)
        if to_date is not None:
            sq = sq.filter(models.AttendanceSession.date <= to_date)
        sessions = sq.all()
        n_sessions = len(sessions)
        if n_sessions == 0:
            continue
        total_sessions_all += n_sessions

        class_students = (
            db.query(models.Student)
            .filter(
                models.Student.class_id == classroom.id,
                models.Student.status == "active",
            )
            .order_by(models.Student.roll_number, models.Student.name)
            .all()
        )
        total_students_all += len(class_students)
        session_ids = [s.id for s in sessions]
        records = (
            db.query(models.AttendanceRecord)
            .filter(models.AttendanceRecord.session_id.in_(session_ids))
            .all()
        )
        by_student: dict[int, dict[str, int]] = {}
        for r in records:
            bucket = by_student.setdefault(
                r.student_id,
                {"present": 0, "absent": 0, "excused": 0, "needs_review": 0},
            )
            if r.status in bucket:
                bucket[r.status] += 1

        for st in class_students:
            c = by_student.get(
                st.id, {"present": 0, "absent": 0, "excused": 0, "needs_review": 0}
            )
            pct = round(c["present"] / n_sessions * 100, 1)
            pct_sum += pct
            students_out.append(
                schemas.ReportStudentOut(
                    student_id=st.student_id,
                    roll_number=st.roll_number,
                    name=st.name,
                    total_sessions=n_sessions,
                    present=c["present"],
                    absent=c["absent"],
                    excused=c["excused"],
                    needs_review=c["needs_review"],
                    attendance_percentage=pct,
                )
            )

    avg = round(pct_sum / len(students_out), 1) if students_out else 0.0
    return schemas.ReportSummaryOut(
        students=students_out,
        class_totals=schemas.ClassTotalsOut(
            total_sessions=total_sessions_all,
            total_students=total_students_all,
            avg_attendance_percentage=avg,
        ),
    )
