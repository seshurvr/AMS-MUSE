"""Students CRUD, duplicate validation, CSV import."""
from pathlib import Path

from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parent.parent
SEED_CSV = BACKEND_DIR / "seed_demo.csv"


def _student_payload(test_class: dict, sid: str = "S1", roll: str = "1",
                     name: str = "Test Student") -> dict:
    return {
        "class_id": test_class["id"],
        "student_id": sid,
        "roll_number": roll,
        "name": name,
    }


def test_create_student(client: TestClient, teacher_headers: dict,
                        test_class: dict):
    r = client.post("/api/students", json=_student_payload(test_class),
                    headers=teacher_headers)
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["student_id"] == "S1"
    assert body["roll_number"] == "1"
    assert body["class_id"] == test_class["id"]
    assert body["status"] == "active"


def test_duplicate_roll_number_rejected(client: TestClient, teacher_headers: dict,
                                       test_class: dict):
    client.post("/api/students", json=_student_payload(test_class),
                headers=teacher_headers)
    r = client.post(
        "/api/students",
        json=_student_payload(test_class, sid="S2", roll="1", name="Other"),
        headers=teacher_headers,
    )
    assert r.status_code == 400, r.text
    assert "roll" in r.json()["detail"].lower()


def test_duplicate_student_id_rejected(client: TestClient, teacher_headers: dict,
                                       test_class: dict):
    client.post("/api/students", json=_student_payload(test_class),
                headers=teacher_headers)
    r = client.post(
        "/api/students",
        json=_student_payload(test_class, sid="S1", roll="2", name="Other"),
        headers=teacher_headers,
    )
    assert r.status_code == 400, r.text


def test_get_update_delete_student(client: TestClient, teacher_headers: dict,
                                   test_class: dict):
    r = client.post("/api/students", json=_student_payload(test_class),
                    headers=teacher_headers)
    sid = r.json()["id"]

    r = client.get(f"/api/students/{sid}", headers=teacher_headers)
    assert r.status_code == 200 and r.json()["name"] == "Test Student"

    r = client.put(f"/api/students/{sid}", json={"name": "Renamed"},
                   headers=teacher_headers)
    assert r.status_code == 200 and r.json()["name"] == "Renamed"

    r = client.delete(f"/api/students/{sid}", headers=teacher_headers)
    assert r.status_code == 200 and r.json().get("ok") is True


def test_students_require_auth(client: TestClient, test_class: dict):
    r = client.post("/api/students", json=_student_payload(test_class))
    assert r.status_code == 401


def test_csv_import_seed_file(client: TestClient, teacher_headers: dict,
                              test_class: dict):
    """Import the repo's own seed_demo.csv through the API."""
    assert SEED_CSV.exists(), f"missing {SEED_CSV}"
    with open(SEED_CSV, "rb") as f:
        content = f.read()
    assert content.splitlines()[0].decode() == "student_id,roll_number,name"

    r = client.post(
        f"/api/classes/{test_class['id']}/students/import",
        files={"file": ("seed_demo.csv", content, "text/csv")},
        headers=teacher_headers,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["imported"] == 10, body
    assert body["skipped"] == 0
    assert body["errors"] == []

    # Students are listed on the class afterwards.
    r = client.get(f"/api/classes/{test_class['id']}/students",
                   headers=teacher_headers)
    assert r.status_code == 200
    assert len(r.json()) == 10

    # Re-importing the same file skips every row (no duplicates created).
    r = client.post(
        f"/api/classes/{test_class['id']}/students/import",
        files={"file": ("seed_demo.csv", content, "text/csv")},
        headers=teacher_headers,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["imported"] == 0
    assert body["skipped"] == 10


def test_csv_import_bad_headers_rejected(client: TestClient, teacher_headers: dict,
                                         test_class: dict):
    bad = b"foo,bar,baz\n1,2,3\n"
    r = client.post(
        f"/api/classes/{test_class['id']}/students/import",
        files={"file": ("bad.csv", bad, "text/csv")},
        headers=teacher_headers,
    )
    assert r.status_code == 400, r.text


def test_csv_import_non_csv_rejected(client: TestClient, teacher_headers: dict,
                                     test_class: dict):
    r = client.post(
        f"/api/classes/{test_class['id']}/students/import",
        files={"file": ("data.txt", b"hello", "text/plain")},
        headers=teacher_headers,
    )
    assert r.status_code == 400, r.text


def test_csv_import_row_errors_reported(client: TestClient, teacher_headers: dict,
                                        test_class: dict):
    csv_bytes = b"student_id,roll_number,name\nS1,1,Good Student\nS2,,\n"
    r = client.post(
        f"/api/classes/{test_class['id']}/students/import",
        files={"file": ("partial.csv", csv_bytes, "text/csv")},
        headers=teacher_headers,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["imported"] == 1
    assert len(body["errors"]) == 1
    assert body["errors"][0]["row"] == 3
