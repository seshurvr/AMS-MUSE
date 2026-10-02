"""Pydantic v2 request/response schemas."""
from datetime import date, datetime, time
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field

RecordStatus = Literal["present", "absent", "excused", "needs_review"]
UserRole = Literal["teacher", "admin"]
SessionStatus = Literal["uploaded", "processing", "processed", "failed", "finalized"]


class _Out(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---------- Auth ----------
class LoginIn(BaseModel):
    username: str = Field(min_length=1)  # username OR email
    password: str = Field(min_length=1)


class PasswordChangeIn(BaseModel):
    current_password: str = Field(min_length=1)
    new_password: str = Field(min_length=8, max_length=128)


class UserOut(_Out):
    id: int
    username: str
    email: str
    role: str
    created_at: datetime


class LoginOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


# ---------- Classes ----------
class ClassCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    section: str = Field(min_length=1, max_length=32)
    subject: str = Field(min_length=1, max_length=128)
    academic_year: str = Field(min_length=1, max_length=16)


class ClassUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=128)
    section: Optional[str] = Field(default=None, min_length=1, max_length=32)
    subject: Optional[str] = Field(default=None, min_length=1, max_length=128)
    academic_year: Optional[str] = Field(default=None, min_length=1, max_length=16)


class ClassOut(_Out):
    id: int
    name: str
    section: str
    subject: str
    academic_year: str
    teacher_id: int
    status: str
    student_count: int = 0
    created_at: datetime
    updated_at: datetime


# ---------- Students ----------
class StudentCreate(BaseModel):
    class_id: int
    student_id: str = Field(min_length=1, max_length=64)
    roll_number: str = Field(min_length=1, max_length=32)
    name: str = Field(min_length=1, max_length=255)
    email: Optional[EmailStr] = None


class StudentUpdate(BaseModel):
    student_id: Optional[str] = Field(default=None, min_length=1, max_length=64)
    roll_number: Optional[str] = Field(default=None, min_length=1, max_length=32)
    name: Optional[str] = Field(default=None, min_length=1, max_length=255)
    email: Optional[EmailStr] = None


class StudentOut(_Out):
    id: int
    student_id: str
    roll_number: str
    name: str
    email: Optional[str] = None
    class_id: int
    status: str
    created_at: datetime
    updated_at: datetime


class ClassDetailOut(ClassOut):
    students: List[StudentOut] = []


class CsvImportError(BaseModel):
    row: int
    message: str


class CsvImportResult(BaseModel):
    imported: int
    skipped: int
    errors: List[CsvImportError] = []


# ---------- Attendance ----------
class SessionCreate(BaseModel):
    class_id: int
    date: date
    session_time: time
    subject: str = Field(min_length=1, max_length=128)
    notes: Optional[str] = None


class SessionOut(_Out):
    id: int
    class_id: int
    date: date
    session_time: time
    subject: str
    notes: Optional[str] = None
    image_width: Optional[int] = None
    image_height: Optional[int] = None
    processing_status: str
    processing_error: Optional[str] = None
    total_students: int
    detected_count: int
    present_count: int
    absent_count: int
    excused_count: int
    review_count: int
    created_by: int
    created_at: datetime
    updated_at: datetime


class ImageQualityOut(BaseModel):
    width: int
    height: int
    brightness: float
    blur_score: float
    warnings: List[str] = []


class ImageUploadOut(BaseModel):
    image_url: str
    quality: ImageQualityOut


class DetectionOut(_Out):
    id: int
    detection_number: int
    x: float
    y: float
    width: float
    height: float
    confidence: float


class ProcessOut(BaseModel):
    detections: List[DetectionOut]
    count: int


class RecordStudentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    student_id: str
    roll_number: str
    name: str


class RecordOut(_Out):
    id: int
    session_id: int
    status: str
    detection_id: Optional[int] = None
    manually_confirmed: bool
    notes: Optional[str] = None
    student: RecordStudentOut
    created_at: datetime
    updated_at: datetime


class RecordIn(BaseModel):
    student_id: int
    status: RecordStatus
    detection_id: Optional[int] = None
    manually_confirmed: bool = False
    notes: Optional[str] = None


class RecordsUpdateIn(BaseModel):
    records: List[RecordIn] = Field(min_length=1)


class FinalizeIn(BaseModel):
    records: Optional[List[RecordIn]] = None


class SessionSummaryOut(BaseModel):
    total: int
    detected: int
    present: int
    absent: int
    excused: int
    needs_review: int
    attendance_percentage: float


class SessionDetailOut(BaseModel):
    session: SessionOut
    detections: List[DetectionOut]
    records: List[RecordOut]
    image_url: Optional[str] = None
    summary: SessionSummaryOut


class HistoryItemOut(BaseModel):
    id: int
    date: date
    session_time: time
    class_name: str
    section: str
    subject: str
    total: int
    present: int
    absent: int
    excused: int
    needs_review: int
    status: str


# ---------- Reports ----------
class ReportStudentOut(BaseModel):
    student_id: str
    roll_number: str
    name: str
    total_sessions: int
    present: int
    absent: int
    excused: int
    needs_review: int
    attendance_percentage: float


class ClassTotalsOut(BaseModel):
    total_sessions: int
    total_students: int
    avg_attendance_percentage: float


class ReportSummaryOut(BaseModel):
    students: List[ReportStudentOut]
    class_totals: ClassTotalsOut


# ---------- Admin ----------
class AdminUserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=64)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    role: UserRole = "teacher"


class AuditLogOut(_Out):
    id: int
    user_id: Optional[int] = None
    username: Optional[str] = None
    action: str
    record_type: Optional[str] = None
    record_id: Optional[int] = None
    timestamp: datetime
