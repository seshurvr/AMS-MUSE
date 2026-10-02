# Student Photo Attendance System

A complete, production-oriented attendance system: a teacher registers classes
and students (with photos), captures a classroom group photo, and the system
detects faces and *suggests* who is who. **The teacher always reviews and
corrects every suggestion before attendance is finalized** — automatic
recognition is never the final word.

- **One Flutter/Dart codebase** for Android and Web/Desktop (Material 3,
  responsive: bottom navigation on phones, navigation rail on desktop).
- **Python/FastAPI backend** with PostgreSQL (SQLite for lightweight dev),
  Alembic migrations, JWT auth, and a swappable face-recognition pipeline.
- **Face detection → embedding → matching** isolated behind interfaces, so
  models can be replaced without touching the API.

> **Status: Milestone 1** — repository architecture, Flutter app shell with
> auth/classes/students/attendance-review flows, FastAPI + PostgreSQL
> foundation, Docker Compose, CI. Face-recognition matching (Milestone 3) and
> student photo registration (Milestone 2) build on this foundation.
> See [Roadmap](#roadmap).

---

## Table of contents

- [Architecture](#architecture)
- [Technology stack](#technology-stack)
- [Folder structure](#folder-structure)
- [Prerequisites](#prerequisites)
- [Environment configuration](#environment-configuration)
- [Database setup](#database-setup)
- [Running with Docker (recommended)](#running-with-docker-recommended)
- [Running the backend locally](#running-the-backend-locally)
- [Running the Flutter app](#running-the-flutter-app)
- [Recognition model setup](#recognition-model-setup)
- [Testing](#testing)
- [GitHub Actions CI](#github-actions-ci)
- [Security](#security)
- [Privacy](#privacy)
- [Attendance logic & formulas](#attendance-logic--formulas)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)

---

## Architecture

```
┌──────────────────────────────┐        ┌──────────────────────────────────┐
│  Flutter (one codebase)      │        │  FastAPI backend                 │
│  Android APK · Flutter Web   │        │                                  │
│                              │ /api/  │  /api/auth        JWT login      │
│  screens:                    │───────▶│  /api/classes     classes        │
│   login → dashboard          │        │  /api/students    students       │
│   classes / students         │        │  /api/attendance  sessions       │
│   take attendance wizard     │        │    ├─ upload photo               │
│   review (photo + boxes)     │        │    ├─ detect faces               │
│   confirm & finalize         │        │    ├─ (M3) match students       │
│   history / reports          │        │    └─ records, finalize         │
│   settings                   │        │  /api/reports     summaries      │
└──────────────────────────────┘        │  /api/export      csv/xlsx       │
                                        └─────────┬────────────┬───────────┘
                                                  │            │
                                        PostgreSQL 16      ./uploads/
                                        (pg-data volume)   (app-uploads)
```

**Request flow for a classroom photo**

```
Flutter → POST /api/attendance/sessions/{id}/image → validation + quality check
        → POST /api/attendance/sessions/{id}/process
            → face detection → (M3) embedding → (M3) matching
            → detections persisted
        → GET  /api/attendance/sessions/{id} → review screen
        → PUT  .../records   (teacher corrections, manual marks)
        → POST .../finalize  (teacher-confirmed save)
```

Three stages stay separate, always:

1. **Face detection** — "there is a face here" (bounding boxes + confidence).
2. **Face recognition** (Milestone 3) — "this looks like student X" (suggestion
   + confidence + MATCHED / UNCERTAIN / UNKNOWN).
3. **Attendance decision** — made only by the teacher on the review screen.

---

## Technology stack

| Layer      | Technology |
|------------|------------|
| Frontend   | Flutter 3 (Dart), Material 3, `provider`, `http`, `shared_preferences`, `image_picker`, `file_picker` |
| Backend    | Python 3.12, FastAPI, Pydantic v2, SQLAlchemy 2, Alembic, PyJWT, passlib/bcrypt, slowapi |
| Database   | PostgreSQL 16 (production, via Compose); SQLite (lightweight local dev) |
| CV         | OpenCV (`opencv-python-headless`); M1: HOG person detection + image quality; M3: YuNet face detection + SFace embeddings behind swappable interfaces |
| Exports    | `openpyxl` (XLSX), stdlib `csv` |
| Shipping   | Docker + Compose; nginx serving the Flutter web build with `/api` reverse proxy |
| CI         | GitHub Actions (`backend.yml`, `flutter.yml`) |

---

## Folder structure

```
.
├── README.md
├── docker-compose.yml          # postgres + backend + flutter web (nginx)
├── .env.example                # all configuration, dev defaults
├── .gitignore
├── .github/workflows/
│   ├── backend.yml             # pip install → ruff → pytest → alembic check → smoke
│   └── flutter.yml             # pub get → analyze → test → build web
├── backend/
│   ├── requirements.txt
│   ├── alembic.ini / alembic/  # migrations (env.py, versions/)
│   ├── Dockerfile
│   ├── seed.py                 # idempotent demo data (dev only)
│   ├── app/
│   │   ├── main.py             # app factory, CORS, rate limiting, /api/health
│   │   ├── config.py           # env-driven settings (incl. FACE_MATCH_THRESHOLD)
│   │   ├── security.py         # bcrypt hashing, JWT create/verify
│   │   ├── database.py         # engine/session (SQLite or PostgreSQL)
│   │   ├── models.py           # SQLAlchemy models
│   │   ├── schemas.py          # Pydantic request/response schemas
│   │   ├── api/                # routes: auth, classes, students, attendance,
│   │   │                       #   reports, export, admin (+ deps.py)
│   │   ├── services/           # attendance, detection, export logic
│   │   ├── cv/                 # detector.py, image_quality.py
│   │   └── recognition/        # (M3) FaceDetector/FaceEmbedder/FaceMatcher
│   └── tests/                  # pytest suite (isolated temp DB)
└── frontend/                   # Flutter project
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart
    │   ├── core/               # config, networking (ApiClient), routing, theme, utils
    │   ├── models/             # typed API models (fromJson/toJson, no codegen)
    │   ├── services/           # auth/class/student/attendance/report/admin/image
    │   ├── providers/          # ChangeNotifier state (auth, classes, students,
    │   │                       #   attendance review, dashboard, reports)
    │   ├── screens/            # auth, shell, dashboard, classes, students,
    │   │                       #   attendance (wizard/review/confirm/history/detail),
    │   │                       #   reports, settings
    │   └── widgets/            # common + image_review/detection_overlay.dart
    ├── test/                   # widget + unit tests
    ├── web/                    # index.html, manifest.json
    ├── android/                # Gradle scaffold (camera permissions included)
    ├── Dockerfile              # flutter build web → nginx
    └── nginx.conf              # SPA fallback + /api proxy
```

---

## Prerequisites

- **Docker + Compose** (for the one-command path), *or*
- **Python 3.12+** with `venv`, **Flutter SDK (stable channel)**, and
  **PostgreSQL 16** (optional — SQLite works for local backend dev).

---

## Environment configuration

```bash
cp .env.example .env        # root: compose-level defaults
cp backend/.env.example backend/.env
```

Key variables (see `.env.example` for the full list):

| Variable | Default (dev) | Notes |
|---|---|---|
| `DATABASE_URL` | `sqlite:///./data/app.db` | Compose overrides to `postgresql+psycopg://…@postgres:5432/attendance` |
| `JWT_SECRET` | `dev-only-change-me` | **Must** be a long random string in production (`openssl rand -hex 32`) |
| `UPLOAD_DIRECTORY` | `./uploads` | Server-side photo storage (never public) |
| `MAX_UPLOAD_SIZE` | `10485760` | 10 MB |
| `FACE_MATCH_THRESHOLD` | `0.70` | M3: cosine-similarity threshold for MATCHED. Tune on a validation set; the default is a starting point, not a universal truth |
| `FACE_UNCERTAIN_THRESHOLD` | `0.55` | M3: below this → UNKNOWN, between → UNCERTAIN |
| `IMAGE_RETENTION_DAYS` | `90` | Classroom-image retention policy |
| `CORS_ORIGINS` | `http://localhost:8080` | Comma-separated |
| `RATE_LIMIT_LOGIN` | `10/minute` | slowapi; 429 JSON on excess |

Never commit `.env`, secrets, or real credentials.

---

## Database setup

**PostgreSQL (production)** — provided by Compose, nothing to do manually.
To use PostgreSQL outside Compose:

```bash
createdb attendance
export DATABASE_URL=postgresql+psycopg://attendance:secret@localhost:5432/attendance
cd backend && alembic upgrade head
```

**Migrations** (Alembic; models stay the source of truth):

```bash
cd backend
alembic revision --autogenerate -m "describe the change"
alembic upgrade head
```

**SQLite (lightweight dev)** — the default `DATABASE_URL`; tables are created
automatically on startup.

**Demo data** (dev only — 20 fictional students, never real names/photos):

```bash
cd backend
python seed.py
# admin@demo.local / Admin1234!   ·   teacher@demo.local / Demo1234!
```

---

## Running with Docker (recommended)

```bash
docker compose up --build
```

- Backend API: http://localhost:8000 (health: `/api/health`, docs: `/docs`)
- Flutter web app: http://localhost:8080
- The backend waits for PostgreSQL to be healthy before starting.
- Demo login: `teacher@demo.local` / `Demo1234!`

---

## Running the backend locally

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # then edit JWT_SECRET etc.
uvicorn app.main:app --reload --port 8000
```

Health check: `curl http://localhost:8000/api/health`

---

## Running the Flutter app

```bash
cd frontend
flutter pub get
```

**Web (dev)** — point at your backend:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

**Web (production build)** — relative `/api` so nginx can proxy it:

```bash
flutter build web --release --dart-define=API_BASE_URL=/api
```

**Android** — install the APK on a device/emulator, then set the server URL
in the app (Settings → Server connection), e.g. `http://192.168.1.5:8000`:

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.5:8000
```

The login screen also exposes the server URL so testers can re-point the app
without rebuilding.

---

## Recognition model setup

Milestone 1 ships **face/person detection + image-quality analysis** behind
stable interfaces. Milestone 3 adds the matching pipeline:

```
backend/app/recognition/
    detector.py     # FaceDetector interface → YuNet (OpenCV DNN) implementation
    embedder.py     # FaceEmbedder interface → SFace (OpenCV DNN) implementation
    matcher.py      # FaceMatcher: cosine similarity vs enrolled embeddings
```

- `FACE_DETECTOR` / `FACE_EMBEDDER` in `.env` select the implementation;
  replace either by implementing the interface — routes never touch models
  directly.
- Model files are downloaded once (see `backend/scripts/download_models.sh`
  in M3) and loaded lazily; tests use deterministic fakes, so CI needs no
  model downloads.
- `FACE_MATCH_THRESHOLD` is validated against a labeled validation set and
  documented — never presented as universally correct.

---

## Testing

**Backend** (47 tests; isolated temp SQLite DB + temp upload dir per run —
your `./data/app.db` is never touched):

```bash
cd backend
source .venv/bin/activate
python -m pytest tests/ -q
ruff check app tests seed.py
```

Coverage: auth & authorization, class/student CRUD, photo upload &
validation, image quality, detection, attendance sessions, record upserts,
finalization, reports, CSV/XLSX export, rate limiting.

**Frontend**:

```bash
cd frontend
flutter test        # model parsing, review-state logic (duplicate guard…), login UI
flutter analyze --no-fatal-infos --no-fatal-warnings
```

**Integration path** (manual end-to-end, scripted in M7): login → create
class → add students → create session → upload photo → process → review →
correct a match → finalize → history → export.

---

## GitHub Actions CI

| Workflow | Steps | Secrets |
|---|---|---|
| `backend.yml` | pip install → `ruff check` → `pytest` → Alembic upgrade/downgrade/upgrade → `/api/health` smoke test | none |
| `flutter.yml` | `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build web` | none |

---

## Security

- Passwords hashed with **bcrypt**; never stored or logged in plaintext.
- **JWT** (HS256) bearer tokens; 401 anywhere in the app drops the session
  and returns to login.
- **Authorization**: teachers access only their own classes/sessions;
  admin-only routes guarded (`require_admin`).
- **Rate limiting** (slowapi) on login (`10/minute` default) plus a global
  default limit; 429 returns actionable JSON.
- **Upload validation**: extension + MIME allowlist, size cap, empty-file and
  corrupt-image rejection, UUID storage names, no public image directory —
  photos are served only via authenticated `/api/files/{name}` with an
  ownership check, never exposing real filesystem paths.
- **Input validation**: Pydantic schemas on every request; SQLAlchemy ORM
  throughout (no raw SQL string building).
- **CORS** allowlist via `CORS_ORIGINS`.
- **Audit log** (`audit_logs` table): login/logout, class/student changes,
  photo add/delete, session create/process/correct/finalize, exports,
  image deletions — user, action, record id, timestamp.
- Never exposed: password hashes, tokens, DB credentials, internal paths,
  raw face embeddings (M3 — embeddings never leave the server; the Flutter
  app only receives match suggestions with confidence scores).

---

## Privacy

This system processes **biometric information** (face embeddings, M3).
Accordingly:

- Face recognition output is a **suggestion with a confidence score**, never
  an identification. The teacher reviews and confirms every match; the UI
  states this and never claims 100% accuracy.
- **Embeddings are biometric data**: stored server-side only, excluded from
  all frontend APIs, never logged, access-controlled like credentials.
- **Image retention** is configurable (`IMAGE_RETENTION_DAYS`): keep
  indefinitely, 7/30/90 days, or delete after finalization. Deleting a
  classroom image never deletes attendance records.
- Students/parents can request **deletion** of photos and embeddings
  (student photo delete endpoint; class/student archive).
- Separate identity data (names, roll numbers) from recognition internals;
  audit administrative actions.

---

## Attendance logic & formulas

- Detected + matched students are **suggested** as present.
- Students not detected are **never auto-marked absent** — they start as
  `needs_review` and the teacher explicitly sets present / absent / excused.
- Detection count ≠ present count, by design.
- Each record tracks `manually_confirmed` (automatic vs manual source).
- Finalization requires confirmation when unresolved (`needs_review`)
  records exist.
- Attendance % = `present ÷ (present + absent + excused) × 100` —
  `needs_review` is never counted as absent.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `401` on every request | Token expired — log in again. Check `JWT_SECRET` is identical across backend restarts. |
| `429 Too many requests` on login | slowapi rate limit tripped; wait a minute or raise `RATE_LIMIT_LOGIN`. |
| Backend can't reach Postgres in Compose | `postgres` healthcheck must pass first; check `docker compose logs postgres`. |
| `alembic upgrade head` fails on Postgres | Ensure the URL uses `postgresql+psycopg://` (the `env.py` rewrites `postgres://` automatically). |
| Flutter web calls the wrong API host | Rebuild with `--dart-define=API_BASE_URL=…`; on Android set it in Settings → Server connection. |
| Photo upload rejected | JPG/PNG/WebP only, ≤ 10 MB (`MAX_UPLOAD_SIZE`), must decode as an image. |
| "No faces detected" | Photo too dark/blurry/small — the upload response includes quality warnings; retake with better lighting. |
| CI `flutter build web` fails | Run `flutter pub get` locally; check `flutter analyze` output. |

---

## Roadmap

- [x] **M1** — Architecture, Flutter app shell (auth → dashboard → classes →
      students → take-attendance wizard → review → confirm → history →
      reports → settings), FastAPI + PostgreSQL + Alembic + Docker + CI.
- [ ] **M2** — Student photo registration (`POST /api/students/{id}/photos`
      with one-face validation), photo management UI.
- [ ] **M3** — Face recognition engine (YuNet + SFace behind interfaces),
      embedding storage, cosine matching with `FACE_MATCH_THRESHOLD`,
      MATCHED/UNCERTAIN/UNKNOWN suggestions in review.
- [ ] **M4** — Camera capture polish, recognition review UX refinements.
- [ ] **M5** — Reports & exports hardening.
- [ ] **M6** — Security/privacy audit, image retention jobs, performance.
- [ ] **M7** — End-to-end tests, docs, production cleanup.

Demo credentials are development-only and documented in
[Database setup](#database-setup); never hard-code production passwords.
