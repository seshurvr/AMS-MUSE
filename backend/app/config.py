"""Application configuration loaded from environment variables."""
from functools import lru_cache
from typing import List

from pydantic import AliasChoices, Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    DATABASE_URL: str = "sqlite:///./data/app.db"
    # Accept JWT_SECRET / UPLOAD_DIR as aliases so docker-based setups keep working.
    SECRET_KEY: str = Field(
        default="dev-only-change-me",
        validation_alias=AliasChoices("SECRET_KEY", "JWT_SECRET"),
    )
    UPLOAD_DIRECTORY: str = Field(
        default="./uploads",
        validation_alias=AliasChoices("UPLOAD_DIRECTORY", "UPLOAD_DIR"),
    )
    MAX_UPLOAD_SIZE: int = 10 * 1024 * 1024
    DETECTION_CONFIDENCE_THRESHOLD: float = 0.5
    # --- Face recognition (Milestone 3). Threshold is configurable, not magic:
    # tune on a validation set and document the chosen value. ---
    FACE_MATCH_THRESHOLD: float = 0.70
    FACE_UNCERTAIN_THRESHOLD: float = 0.55
    FACE_DETECTOR: str = "opencv_yunet"  # swappable: see app/recognition/
    FACE_EMBEDDER: str = "opencv_sface"  # swappable: see app/recognition/
    FACE_MAX_IMAGE_DIM: int = 1600
    RECOGNITION_TIMEOUT_SECONDS: int = 120
    # --- Auth rate limiting (slowapi "N/minute" strings) ---
    RATE_LIMIT_LOGIN: str = "10/minute"
    RATE_LIMIT_DEFAULT: str = "200/minute"
    IMAGE_RETENTION_DAYS: int = 90
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480
    CORS_ORIGINS: List[str] = ["http://localhost:5173"]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def _split_origins(cls, v):
        if isinstance(v, str):
            return [o.strip() for o in v.split(",") if o.strip()]
        return v


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
