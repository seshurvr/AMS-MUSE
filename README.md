# Classroom Photo Attendance Management System

Take a photo of a classroom, detect the people in it, and let the teacher confirm
who's who — turning a single picture into a marked attendance register.

## Features

- **JWT auth** with teacher / admin demo accounts (dev only)
- **Classes & students** CRUD, plus bulk student import from CSV
- **Attendance sessions**: create a session, upload a classroom photo, run
  person detection, then map each detected box to a student
- **Teacher-confirmed mapping** — the system never identifies anyone by itself
  (see Privacy note)
- **Attendance records** with statuses `present` / `absent` / `excused` /
  `needs_review`; finalize a session to lock it
- **Reports**: per-session summary and history
- **Exports**: attendance as CSV or XLSX

## Privacy note — no biometric identification

This system performs **person detection only** (bounding boxes: "there is a person
here"). It does **not** perform facial recognition or any biometric
identification, and it never maps a face to an identity automatically. Every
box-to-student mapping is made explicitly by the teacher in the review UI, and
every attendance mark can be corrected before a session is finalized.

## Architecture

```
┌─────────────────────┐        ┌──────────────────────────────┐
│  React + Vite SPA   │        │  FastAPI backend             │
│  (nginx in prod)    │        │                              │
│                     │ /api/  │  /api/auth      JWT login    │
│  pages:             │───────▶│  /api/classes   classes      │
│   login             │        │  /api/students  students     │
│   classes/students  │        │  /api/attendance sessions   │
│   sessions          │        │    ├─ upload photo           │
│   review boxes      │        │    ├─ detect (HOG/YOLO)      │
│   reports/exports   │        │    └─ records, finalize      │
│                     │        │  /api/reports   summaries    │
└─────────────────────┘        │  /api/export    csv/xlsx     │
                               └──────┬───────────────┬───────┘
                                      │               │
                                 ./data/app.db    ./uploads/
                                 (SQLite)         (photos)
```

In production (`docker compose`), nginx serves the built SPA and proxies
`/api/` to the backend container; both share named volumes for the database
and uploaded photos.

## Tech stack

| Layer    | Technology |
|----------|------------|
| Backend  | Python 3.12, FastAPI, SQLAlchemy, SQLite, PyJWT |
| CV       | OpenCV (`opencv-python-headless`), HOG person detector (YOLO-swappable) |
| Frontend | React 19 + TypeScript, Vite |
| Serving  | nginx (static SPA + `/api/` reverse proxy) |
| Shipping | Docker + Docker Compose |
| Tests    | pytest, FastAPI TestClient |

## Quick start

### Option A — Docker (recommended, one command)

```bash
docker compose up --build
```

- Frontend: http://localhost:8080
- API: http://localhost:8000 (docs at http://localhost:8000/docs)
- Demo login (dev only): `teacher@demo.local` / `Demo1234!`
  (admin: `admin@demo.local` / `Admin1234!`)
- Data persists in the `app-data` and `app-uploads` Docker volumes.

The backend container runs `seed.py` on startup (idempotent), so the demo
accounts exist on first boot.

### Option B — local development

Backend:

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python seed.py          # create tables + demo users (dev only)
uvicorn app.main:app --reload --port 8000
```

Frontend:

```bash
cd frontend
npm install
npm run dev             # http://localhost:5173, proxies /api to :8000
```

Production frontend build: `npm run build` outputs `dist/`, served by the
nginx stage of `frontend/Dockerfile`.

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `sqlite:///./data/app.db` (local) / `sqlite:////app/data/app.db` (compose) | SQLAlchemy database URL |
| `DATA_DIR` | `./data` (local) / `/app/data` (compose) | Directory holding the SQLite file |
| `UPLOAD_DIR` | `./uploads` (local) / `/app/uploads` (compose) | Directory for uploaded classroom photos |
| `JWT_SECRET` | `dev-only-change-me-in-production` (compose) | **Must be a long random string in production** |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `60` | JWT lifetime |
| `CORS_ORIGINS` | `http://localhost:5173,http://localhost:8080` | Allowed browser origins |

Copy `backend/.env.example` to `backend/.env` to override locally or in
compose (the compose file treats `.env` as optional — defaults apply without it).
**No secrets are hard-coded**; anything sensitive comes from the environment.

## Database setup & seed

```bash
cd backend
python seed.py
```

`seed.py` creates the tables and inserts the demo accounts (idempotent — it
skips users that already exist):

| Username | Password | Role |
|----------|----------|------|
| `teacher@demo.local` | `Demo1234!` | teacher |
| `admin@demo.local` | `Admin1234!` | admin |

⚠️ **Dev only.** These credentials are for local/demo use. In production, seed
real users through your own provisioning and set a strong `JWT_SECRET`.

`backend/seed_demo.csv` is a sample student import file
(header `student_id,roll_number,name`, 10 fictional demo rows) you can upload via
`POST /api/classes/{id}/students/import` to try the CSV import flow.

## Computer vision notes

- **Default detector: HOG** (`cv2.HOGDescriptor` with the default people
  detector). It needs no model download, runs on CPU, and is good enough for
  clear, front-facing classroom photos.
- Detection output per box: `detection_number`, `x`, `y`, `width`, `height`,
  `confidence`. Boxes are person locations only — no identity.
- **Swapping in YOLO**: the detection code lives behind a small detector
  interface (`backend/app/services/detection.py`). To use YOLO (e.g.
  `ultralytics`), implement the same `detect(image) -> list[dict]` function
  returning the box dicts above and point the service at it; add `ultralytics`
  to `requirements.txt` and the model weights to the image (or download at
  build time). No API changes are needed — the frontend only consumes boxes.
- `image_quality` scores an uploaded photo (brightness/blur heuristics) so the
  UI can warn about dark or blurry shots before detection runs.

## API summary

Base path `/api`. Auth: `Authorization: Bearer <access_token>`.

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/login` | `{username, password}` → `{access_token, token_type, ...}` |
| GET | `/api/auth/me` | Current user |
| GET/POST | `/api/classes` | List / create classes |
| GET/PUT/DELETE | `/api/classes/{id}` | Read / update / delete (archive) a class |
| POST | `/api/classes/{id}/students/import` | Multipart CSV import (`student_id,roll_number,name`) |
| GET/POST | `/api/students` | List / create students |
| GET/PUT/DELETE | `/api/students/{id}` | Read / update / delete a student |
| POST | `/api/attendance/sessions` | Create an attendance session for a class |
| POST | `/api/attendance/sessions/{id}/image` | Upload the classroom photo (multipart) |
| POST | `/api/attendance/sessions/{id}/process` | Run detection → `{detections: [...], count}` |
| GET | `/api/attendance/sessions/{id}` | Session detail incl. detections & records |
| PUT | `/api/attendance/sessions/{id}/records` | Teacher-confirmed box→student mapping + statuses |
| POST | `/api/attendance/sessions/{id}/finalize` | Lock the session |
| GET | `/api/attendance/history` | Past sessions |
| GET | `/api/reports/summary` | Attendance summary counts |
| GET | `/api/export/attendance?session_id=&format=csv\|xlsx` | Download the register |
| GET | `/api/health` | Health check (no auth) |

Full interactive docs: http://localhost:8000/docs when the backend runs.

## Testing

```bash
cd backend
pip install -r requirements.txt        # includes pytest + httpx
python -m pytest tests -q
```

The suite (`backend/tests/`) runs against an **isolated temp SQLite DB and temp
upload dir** (via env vars set in `conftest.py`) — your dev `./data/app.db` is
never touched. It covers auth, classes, students + CSV import, the full
attendance flow (create → upload generated image → process → map → finalize),
the HOG detector on synthetic images, and CSV/XLSX export.

## Security & privacy considerations

- Passwords are hashed (never stored or logged in plain text); auth is via
  short-lived JWT bearer tokens.
- No hard-coded secrets: `JWT_SECRET` and all config come from the environment.
- No facial recognition or biometric templates anywhere in the pipeline —
  detection outputs anonymous boxes; identity mapping is always a deliberate
  teacher action.
- Uploaded photos are stored under `UPLOAD_DIR` and served only to
  authenticated users of the owning class context.
- Validate uploads server-side (image type/size limits) before processing.

## Image retention

Classroom photos are kept under `UPLOAD_DIR` (`./uploads` locally, the
`app-uploads` volume in compose) so teachers can review detections. To purge:

```bash
# local dev
rm ./uploads/*
# docker
docker compose exec backend sh -c 'rm /app/uploads/*'
```

Consider a retention policy (e.g. delete photos N days after a session is
finalized) appropriate to your institution's data-protection rules.

## Troubleshooting

| Symptom | Likely cause / fix |
|---------|--------------------|
| `docker compose up` fails on backend build | Re-run with `--build`; ensure `backend/requirements.txt` exists |
| Frontend shows blank page at :8080 | Backend unhealthy — check `docker compose logs backend`; API must pass `/api/health` |
| `401` on every API call | Token expired or missing `Authorization: Bearer` header; log in again |
| CSV import rejected | Header must be exactly `student_id,roll_number,name`; `roll_number` must be unique per class |
| Detection finds 0 people | HOG needs reasonably clear, front-facing shots; check the image-quality warning; try YOLO (see CV notes) |
| `uvicorn app.main:app` → `ModuleNotFoundError` | Run from `backend/` with the venv activated |
| Tests touch my dev DB | They shouldn't — `conftest.py` forces temp paths; report it as a bug if they do |
