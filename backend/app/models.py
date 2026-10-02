"""SQLAlchemy ORM models. Kept Postgres-compatible (no SQLite-specific SQL)."""
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    Time,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


def utcnow() -> datetime:
    """Naive UTC timestamp (works on both SQLite and Postgres)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    username: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(16), default="teacher")  # teacher|admin
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=utcnow, onupdate=utcnow
    )

    classes: Mapped[list["ClassRoom"]] = relationship(back_populates="teacher")
    sessions: Mapped[list["AttendanceSession"]] = relationship(
        back_populates="created_by_user"
    )


class ClassRoom(Base):
    __tablename__ = "classes"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(128))
    section: Mapped[str] = mapped_column(String(32))
    subject: Mapped[str] = mapped_column(String(128))
    academic_year: Mapped[str] = mapped_column(String(16))
    teacher_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    status: Mapped[str] = mapped_column(
        String(16), default="active"
    )  # active|archived
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=utcnow, onupdate=utcnow
    )

    teacher: Mapped["User"] = relationship(back_populates="classes")
    students: Mapped[list["Student"]] = relationship(
        back_populates="classroom", cascade="all, delete-orphan"
    )
    sessions: Mapped[list["AttendanceSession"]] = relationship(
        back_populates="classroom", cascade="all, delete-orphan"
    )


class Student(Base):
    __tablename__ = "students"
    __table_args__ = (
        UniqueConstraint("class_id", "student_id", name="uq_student_id_per_class"),
        UniqueConstraint("class_id", "roll_number", name="uq_roll_per_class"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    student_id: Mapped[str] = mapped_column(String(64))
    roll_number: Mapped[str] = mapped_column(String(32))
    name: Mapped[str] = mapped_column(String(255))
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"), index=True)
    status: Mapped[str] = mapped_column(
        String(16), default="active"
    )  # active|archived
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=utcnow, onupdate=utcnow
    )

    classroom: Mapped["ClassRoom"] = relationship(back_populates="students")


class AttendanceSession(Base):
    __tablename__ = "attendance_sessions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    class_id: Mapped[int] = mapped_column(ForeignKey("classes.id"), index=True)
    date = mapped_column(Date)
    session_time = mapped_column(Time)
    subject: Mapped[str] = mapped_column(String(128))
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_path: Mapped[str | None] = mapped_column(String(512), nullable=True)
    image_width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    image_height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    processing_status: Mapped[str] = mapped_column(
        String(16), default="uploaded"
    )  # uploaded|processing|processed|failed|finalized
    processing_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    total_students: Mapped[int] = mapped_column(Integer, default=0)
    detected_count: Mapped[int] = mapped_column(Integer, default=0)
    present_count: Mapped[int] = mapped_column(Integer, default=0)
    absent_count: Mapped[int] = mapped_column(Integer, default=0)
    excused_count: Mapped[int] = mapped_column(Integer, default=0)
    review_count: Mapped[int] = mapped_column(Integer, default=0)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=utcnow, onupdate=utcnow
    )

    classroom: Mapped["ClassRoom"] = relationship(back_populates="sessions")
    created_by_user: Mapped["User"] = relationship(back_populates="sessions")
    detections: Mapped[list["Detection"]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="Detection.detection_number",
    )
    records: Mapped[list["AttendanceRecord"]] = relationship(
        back_populates="session", cascade="all, delete-orphan"
    )


class Detection(Base):
    __tablename__ = "detections"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(
        ForeignKey("attendance_sessions.id", ondelete="CASCADE"), index=True
    )
    detection_number: Mapped[int] = mapped_column(Integer)
    x: Mapped[float] = mapped_column(Float)  # original-image pixels
    y: Mapped[float] = mapped_column(Float)
    width: Mapped[float] = mapped_column(Float)
    height: Mapped[float] = mapped_column(Float)
    confidence: Mapped[float] = mapped_column(Float)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    session: Mapped["AttendanceSession"] = relationship(back_populates="detections")


class AttendanceRecord(Base):
    __tablename__ = "attendance_records"
    __table_args__ = (
        UniqueConstraint("session_id", "student_id", name="uq_record_per_session"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    session_id: Mapped[int] = mapped_column(
        ForeignKey("attendance_sessions.id", ondelete="CASCADE"), index=True
    )
    student_id: Mapped[int] = mapped_column(
        ForeignKey("students.id", ondelete="CASCADE"), index=True
    )
    status: Mapped[str] = mapped_column(
        String(16), default="needs_review"
    )  # present|absent|excused|needs_review
    detection_id: Mapped[int | None] = mapped_column(
        ForeignKey("detections.id", ondelete="SET NULL"), nullable=True
    )
    manually_confirmed: Mapped[bool] = mapped_column(Boolean, default=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=utcnow, onupdate=utcnow
    )

    session: Mapped["AttendanceSession"] = relationship(back_populates="records")
    student: Mapped["Student"] = relationship()
    detection: Mapped["Detection | None"] = relationship()


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    action: Mapped[str] = mapped_column(String(128), index=True)
    record_type: Mapped[str | None] = mapped_column(String(64), nullable=True)
    record_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    timestamp: Mapped[datetime] = mapped_column(
        DateTime, default=utcnow, index=True
    )

    user: Mapped["User | None"] = relationship()
