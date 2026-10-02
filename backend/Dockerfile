# Backend: FastAPI classroom attendance API
FROM python:3.12-slim

# System libraries required by opencv-python-headless at import/runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python deps first for better layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App code (+ seed.py at repo root of the backend context)
COPY . .

# Writable locations for the SQLite DB and uploaded classroom photos
RUN mkdir -p /app/data /app/uploads

# Contract defaults: SQLite at ./data/app.db, uploads at ./uploads
ENV DATA_DIR=/app/data \
    UPLOAD_DIR=/app/uploads \
    DATABASE_URL=sqlite:////app/data/app.db

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/health')"

# Seed demo data (idempotent; safe to skip on failure), then serve
CMD ["sh", "-c", "python seed.py || echo 'seed skipped'; exec uvicorn app.main:app --host 0.0.0.0 --port 8000"]
