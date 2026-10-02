"""Classes CRUD + archive flow."""
from fastapi.testclient import TestClient


def _payload(name: str = "Grade 5") -> dict:
    return {
        "name": name,
        "section": "B",
        "subject": "Science",
        "academic_year": "2026-27",
    }


def test_create_class(client: TestClient, teacher_headers: dict):
    r = client.post("/api/classes", json=_payload(), headers=teacher_headers)
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["name"] == "Grade 5"
    assert body["section"] == "B"
    assert body["status"] == "active"
    assert body["student_count"] == 0
    assert body["id"]


def test_list_classes_contains_created(client: TestClient, teacher_headers: dict,
                                       test_class: dict):
    r = client.get("/api/classes", headers=teacher_headers)
    assert r.status_code == 200, r.text
    ids = [c["id"] for c in r.json()]
    assert test_class["id"] in ids


def test_get_class_detail(client: TestClient, teacher_headers: dict,
                          test_class: dict):
    r = client.get(f"/api/classes/{test_class['id']}", headers=teacher_headers)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["id"] == test_class["id"]
    assert body["students"] == []


def test_get_class_404(client: TestClient, teacher_headers: dict):
    r = client.get("/api/classes/999999", headers=teacher_headers)
    assert r.status_code == 404


def test_update_class(client: TestClient, teacher_headers: dict,
                      test_class: dict):
    r = client.put(
        f"/api/classes/{test_class['id']}",
        json={"name": "Grade 5 - Updated", "subject": "Biology"},
        headers=teacher_headers,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["name"] == "Grade 5 - Updated"
    assert body["subject"] == "Biology"


def test_archive_class(client: TestClient, teacher_headers: dict,
                       test_class: dict):
    cid = test_class["id"]
    r = client.delete(f"/api/classes/{cid}", headers=teacher_headers)
    assert r.status_code == 200, r.text
    assert r.json().get("ok") is True

    # Default listing hides archived classes...
    r = client.get("/api/classes", headers=teacher_headers)
    assert cid not in [c["id"] for c in r.json()]

    # ...but the archived filter shows them.
    r = client.get("/api/classes", params={"status": "archived"},
                   headers=teacher_headers)
    assert r.status_code == 200, r.text
    archived = [c for c in r.json() if c["id"] == cid]
    assert archived and archived[0]["status"] == "archived"


def test_classes_require_auth(client: TestClient):
    assert client.get("/api/classes").status_code == 401
    assert client.post("/api/classes", json=_payload()).status_code == 401


def test_create_class_validation(client: TestClient, teacher_headers: dict):
    r = client.post("/api/classes", json={"name": ""}, headers=teacher_headers)
    assert r.status_code == 422
