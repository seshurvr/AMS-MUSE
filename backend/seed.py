"""Seed the database with DEV-ONLY demo data.

Creates:
  - admin@demo.local / Admin1234!        (admin)
  - teacher@demo.local / Demo1234!       (teacher)
  - Class "10th Standard", section A, Mathematics, 2026-27 (owned by teacher)
  - 20 demo students (Demo Student 01..20, STU001.., roll 1..20)
  - 2 finalized historical sessions with plausible attendance records

All names are clearly fake. NEVER run this against a production database.
Run:  DATABASE_URL=sqlite:///./data/app.db python seed.py   (from backend/)
"""
import os
import random
import sys
from datetime import date, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import models  # noqa: F401,E402
from app.database import Base, SessionLocal, engine  # noqa: E402
from app.security import hash_password  # noqa: E402

ADMIN_EMAIL = "admin@demo.local"
ADMIN_PASSWORD = "Admin1234!"
TEACHER_EMAIL = "teacher@demo.local"
TEACHER_PASSWORD = "Demo1234!"


def get_or_create_user(db, username, email, password, role):
    user = db.query(models.User).filter(models.User.email == email).one_or_none()
    if user:
        print(f"  user exists: {email}")
        return user
    user = models.User(
        username=username,
        email=email,
        password_hash=hash_password(password),
        role=role,
    )
    db.add(user)
    db.flush()
    print(f"  created user: {email} ({role})")
    return user


def main() -> None:
    print("=" * 60)
    print("DEV-ONLY SEED — do NOT run against production data")
    print("=" * 60)
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        get_or_create_user(db, "admin", ADMIN_EMAIL, ADMIN_PASSWORD, "admin")
        teacher = get_or_create_user(
            db, "teacher", TEACHER_EMAIL, TEACHER_PASSWORD, "teacher"
        )

        classroom = (
            db.query(models.ClassRoom)
            .filter(
                models.ClassRoom.name == "10th Standard",
                models.ClassRoom.section == "A",
                models.ClassRoom.teacher_id == teacher.id,
            )
            .one_or_none()
        )
        if classroom is None:
            classroom = models.ClassRoom(
                name="10th Standard",
                section="A",
                subject="Mathematics",
                academic_year="2026-27",
                teacher_id=teacher.id,
            )
            db.add(classroom)
            db.flush()
            print("  created class: 10th Standard / A / Mathematics / 2026-27")
        else:
            print("  class exists: 10th Standard / A")

        students = []
        for i in range(1, 21):
            sid = f"STU{i:03d}"
            existing = (
                db.query(models.Student)
                .filter(
                    models.Student.class_id == classroom.id,
                    models.Student.student_id == sid,
                )
                .one_or_none()
            )
            if existing is None:
                existing = models.Student(
                    class_id=classroom.id,
                    student_id=sid,
                    roll_number=str(i),
                    name=f"Demo Student {i:02d}",
                )
                db.add(existing)
            students.append(existing)
        db.flush()
        print("  ensured 20 demo students (Demo Student 01..20)")

        rng = random.Random(42)
        history = [
            (date(2026, 9, 28), time(9, 0)),
            (date(2026, 9, 30), time(9, 0)),
        ]
        for day, at in history:
            session = (
                db.query(models.AttendanceSession)
                .filter(
                    models.AttendanceSession.class_id == classroom.id,
                    models.AttendanceSession.date == day,
                )
                .one_or_none()
            )
            if session is not None:
                print(f"  session exists: {day}")
                continue
            session = models.AttendanceSession(
                class_id=classroom.id,
                date=day,
                session_time=at,
                subject="Mathematics",
                notes="Seeded historical session (demo data).",
                total_students=len(students),
                detected_count=17,
                created_by=teacher.id,
            )
            db.add(session)
            db.flush()
            counts = {"present": 0, "absent": 0, "excused": 0, "needs_review": 0}
            for st in students:
                roll = rng.random()
                if roll < 0.85:
                    status_, confirmed = "present", True
                elif roll < 0.92:
                    status_, confirmed = "absent", True
                elif roll < 0.95:
                    status_, confirmed = "excused", True
                else:
                    status_, confirmed = "needs_review", False
                counts[status_] += 1
                db.add(
                    models.AttendanceRecord(
                        session_id=session.id,
                        student_id=st.id,
                        status=status_,
                        manually_confirmed=confirmed,
                    )
                )
            session.present_count = counts["present"]
            session.absent_count = counts["absent"]
            session.excused_count = counts["excused"]
            session.review_count = counts["needs_review"]
            session.processing_status = "finalized"
            print(
                f"  created finalized session {day} "
                f"(present={counts['present']}, absent={counts['absent']}, "
                f"excused={counts['excused']}, needs_review={counts['needs_review']})"
            )
        db.commit()
    finally:
        db.close()

    print("=" * 60)
    print("DEV-ONLY demo credentials (do not use in production):")
    print(f"  admin:   {ADMIN_EMAIL} / {ADMIN_PASSWORD}")
    print(f"  teacher: {TEACHER_EMAIL} / {TEACHER_PASSWORD}")
    print("=" * 60)


if __name__ == "__main__":
    main()
