"""End-to-end attendance flow.

create session -> upload generated image -> process -> (fake detection insert)
-> teacher maps detection to student -> finalize -> summary/history/reports.
"""
import pytest
from fastapi.testclient import TestClient

from .conftest import insert_fake_detection

SESSION_DATE = "2026-10-02"
SESSION_TIME = "09:00:00"

EXPECTED_DETECTION_KEYS = {
    "detection_number", "x", "y", "width", "height", "confidence",
}


@pytest.fixture()
def classroom_with_students(client: TestClient, teacher_headers: dict,
                            test_class: dict) -> dict:
    """A class with 3 students; returns {'class': ..., 'students': [...]}."""
    students = []
    for i, name in enumerate(["Aarav Test", "Diya Test", "Arjun Test"], start=1):
        r = client.post(
            "/api/students",
            json={
                "class_id": test_class["id"],
                "student_id": f"E2E{i:03d}",
                "roll_number": str(i),
                "name": name,
            },
            headers=teacher_headers,
        )
        assert r.status_code == 201, r.text
        students.append(r.json())
    return {"class": test_class, "students": students}


@pytest.fixture()
def session_id(client: TestClient, teacher_headers: dict,
               classroom_with_students: dict) -> int:
    r = client.post(
        "/api/attendance/sessions",
        json={
            "class_id": classroom_with_students["class"]["id"],
            "date": SESSION_DATE,
            "session_time": SESSION_TIME,
            "subject": "Mathematics",
            "notes": "e2e test session",
        },
        headers=teacher_headers,
    )
    assert r.status_code in (200, 201), f"session create failed: {r.status_code} {r.text}"
    body = r.json()
    assert body["class_id"] == classroom_with_students["class"]["id"]
    assert body["processing_status"] in ("uploaded", "processing")
    return body["id"]


def test_health(client: TestClient):
    r = client.get("/api/health")
    assert r.status_code == 200, r.text


def test_upload_image(client: TestClient, teacher_headers: dict, session_id: int,
                      png_bytes: bytes):
    r = client.post(
        f"/api/attendance/sessions/{session_id}/image",
        files={"file": ("classroom.png", png_bytes, "image/png")},
        headers=teacher_headers,
    )
    assert r.status_code == 200, f"upload failed: {r.status_code} {r.text}"
    body = r.json()
    assert body["image_url"]
    quality = body["quality"]
    for key in ("width", "height", "brightness", "blur_score", "warnings"):
        assert key in quality, f"missing quality key {key}"
    assert quality["width"] == 640 and quality["height"] == 480


def test_process_image_graceful(client: TestClient, teacher_headers: dict,
                                session_id: int, png_bytes: bytes):
    """HOG on a synthetic image usually finds 0 people; the API must not 500."""
    client.post(
        f"/api/attendance/sessions/{session_id}/image",
        files={"file": ("classroom.png", png_bytes, "image/png")},
        headers=teacher_headers,
    )
    r = client.post(f"/api/attendance/sessions/{session_id}/process",
                    headers=teacher_headers)
    assert r.status_code == 200, f"process failed: {r.status_code} {r.text}"
    body = r.json()
    assert body["count"] == len(body["detections"])
    for det in body["detections"]:
        assert EXPECTED_DETECTION_KEYS <= set(det), f"bad detection keys: {det}"
        assert det["confidence"] >= 0


def test_mapping_finalize_and_summary(client: TestClient, teacher_headers: dict,
                                      session_id: int, png_bytes: bytes,
                                      classroom_with_students: dict):
    students = classroom_with_students["students"]

    # Upload + process (synthetic image -> likely 0 detections, must not fail).
    client.post(
        f"/api/attendance/sessions/{session_id}/image",
        files={"file": ("classroom.png", png_bytes, "image/png")},
        headers=teacher_headers,
    )
    r = client.post(f"/api/attendance/sessions/{session_id}/process",
                    headers=teacher_headers)
    assert r.status_code == 200, r.text

    # Manually insert a fake detection row to exercise the mapping flow.
    det = insert_fake_detection(session_id, detection_number=1)

    # Teacher-confirmed mapping: detection -> student, marked present.
    r = client.put(
        f"/api/attendance/sessions/{session_id}/records",
        json={"records": [
            {
                "student_id": students[0]["id"],
                "status": "present",
                "detection_id": det.id,
                "manually_confirmed": True,
                "notes": "mapped in test",
            }
        ]},
        headers=teacher_headers,
    )
    assert r.status_code == 200, f"records update failed: {r.status_code} {r.text}"

    # Session detail reflects the mapping.
    r = client.get(f"/api/attendance/sessions/{session_id}",
                   headers=teacher_headers)
    assert r.status_code == 200, r.text
    detail = r.json()
    assert detail["session"]["id"] == session_id
    assert len(detail["detections"]) >= 1
    statuses = {rec["student"]["id"]: rec["status"] for rec in detail["records"]}
    assert statuses.get(students[0]["id"]) == "present"

    # Finalize: unmapped students are backfilled as needs_review (never absent).
    r = client.post(f"/api/attendance/sessions/{session_id}/finalize",
                    json={}, headers=teacher_headers)
    assert r.status_code == 200, f"finalize failed: {r.status_code} {r.text}"

    r = client.get(f"/api/attendance/sessions/{session_id}",
                   headers=teacher_headers)
    detail = r.json()
    assert detail["session"]["processing_status"] == "finalized"
    summary = detail["summary"]
    assert summary["total"] == 3
    assert summary["present"] == 1
    assert summary["needs_review"] == 2
    assert summary["absent"] == 0
    assert summary["excused"] == 0

    # History lists the finalized session.
    r = client.get("/api/attendance/history", headers=teacher_headers)
    assert r.status_code == 200, r.text
    ids = [h["id"] for h in r.json()]
    assert session_id in ids


def test_reports_summary(client: TestClient, teacher_headers: dict,
                         session_id: int, png_bytes: bytes,
                         classroom_with_students: dict):
    students = classroom_with_students["students"]
    cid = classroom_with_students["class"]["id"]

    client.post(
        f"/api/attendance/sessions/{session_id}/image",
        files={"file": ("classroom.png", png_bytes, "image/png")},
        headers=teacher_headers,
    )
    client.post(f"/api/attendance/sessions/{session_id}/process",
                headers=teacher_headers)
    det = insert_fake_detection(session_id)
    client.put(
        f"/api/attendance/sessions/{session_id}/records",
        json={"records": [{
            "student_id": students[1]["id"],
            "status": "excused",
            "detection_id": det.id,
            "manually_confirmed": True,
        }]},
        headers=teacher_headers,
    )
    client.post(f"/api/attendance/sessions/{session_id}/finalize",
                json={}, headers=teacher_headers)

    r = client.get("/api/reports/summary", params={"class_id": cid},
                   headers=teacher_headers)
    assert r.status_code == 200, f"summary failed: {r.status_code} {r.text}"
    body = r.json()
    assert "students" in body and "class_totals" in body
    by_id = {s["student_id"]: s for s in body["students"]}
    assert by_id["E2E002"]["excused"] == 1
    assert body["class_totals"]["total_sessions"] >= 1


def test_session_requires_auth(client: TestClient):
    assert client.get("/api/attendance/history").status_code == 401
    assert client.post("/api/attendance/sessions", json={}).status_code in (401, 422)
