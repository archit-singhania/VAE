from functools import lru_cache
from typing import Literal

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_SECRET = "development-only-change-before-deploy"


def normalize_database_url(database_url: str) -> str:
    """Use the psycopg 3 driver for common managed-Postgres URL formats."""
    for prefix in ("postgres://", "postgresql://", "postgresql+psycopg2://"):
        if database_url.startswith(prefix):
            return f"postgresql+psycopg://{database_url[len(prefix) :]}"
    return database_url


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="AEVRA_", extra="ignore")

    env: str = "development"
    secret_key: str = Field(default=DEFAULT_SECRET, min_length=32)
    access_token_minutes: int = Field(default=30, ge=5, le=1440)
    session_cookie_name: str = "aevra_session"
    session_cookie_secure: bool | None = None
    session_cookie_samesite: Literal["lax", "strict", "none"] = "lax"
    token_vault_key: str | None = Field(default=None, min_length=32)
    auth_rate_limit_attempts: int = Field(default=10, ge=3, le=100)
    auth_rate_limit_window_seconds: int = Field(default=60, ge=10, le=3600)
    api_rate_limit_attempts: int = Field(default=120, ge=20, le=10_000)
    api_rate_limit_window_seconds: int = Field(default=60, ge=10, le=3600)
    allowed_origins: str = ""
    enable_redis_rate_limit: bool = True
    redis_rate_limit_prefix: str = "aevra:rate-limit"
    database_url: str = "sqlite:///./aevra.db"
    seed_email: str = "owner@aevra.local"
    seed_password: str = Field(default="AevraLocalOnly!2026", min_length=12)
    admin_email: str = "admin@vae.local"
    # Eight characters keeps staging/admin smoke tests usable. Production
    # deployments should still set a unique, generated password in Render.
    admin_password: str = Field(default="VaeAdminLocalOnly!2026", min_length=8)
    admin_display_name: str = "VAE Admin"
    manual_payment_approval_enabled: bool = True
    payment_amount: str = "0"
    payment_currency: str = "INR"
    payment_upi_id: str = ""
    payment_qr_url: str = ""
    payment_support_email: str = "support@vae.local"
    payment_expiry_days: int = Field(default=7, ge=1, le=90)
    embedding_dimensions: int = Field(default=384, ge=64, le=4096)
    knowledge_chunk_chars: int = Field(default=900, ge=200, le=4000)
    knowledge_chunk_overlap: int = Field(default=120, ge=0, le=1000)
    max_document_bytes: int = Field(default=20 * 1024 * 1024, ge=1024)
    embedding_provider: str = "hashing"
    embedding_model: str = "nomic-embed-text"
    ollama_base_url: str = "http://localhost:11434"
    ollama_model: str = "qwen3:8b"
    ollama_timeout_seconds: float = Field(default=120.0, ge=1, le=600)
    groq_api_key: str | None = None
    groq_base_url: str = "https://api.groq.com/openai/v1"
    groq_model: str = "llama-3.1-8b-instant"
    groq_timeout_seconds: float = Field(default=60.0, ge=1, le=600)
    media_root: str = "./media"
    image_provider: str = "deterministic"
    huggingface_api_token: str | None = None
    huggingface_image_model: str = "black-forest-labs/FLUX.1-schnell"
    huggingface_image_inference_provider: str = "fal-ai"
    huggingface_image_timeout_seconds: float = Field(default=120.0, ge=1, le=600)
    flux_base_url: str = "http://localhost:8188"
    flux_timeout_seconds: float = Field(default=120.0, ge=1, le=600)
    video_provider: str = "ffmpeg"
    ffmpeg_binary: str = "ffmpeg"
    ffprobe_binary: str = "ffprobe"
    video_default_seconds: float = Field(default=6.0, ge=0.5, le=60)
    video_max_seconds: float = Field(default=60.0, ge=0.5, le=300)
    video_fps: int = Field(default=30, ge=1, le=60)
    redis_url: str = "redis://localhost:6379/0"
    enable_celery: bool = False
    storage_backend: str = "local"
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "aevra"
    minio_secret_key: str = "aevra-development-only"
    minio_bucket: str = "aevra-assets"
    minio_secure: bool = False
    oauth_state_minutes: int = Field(default=10, ge=2, le=30)
    oauth_redirect_base_url: str = "http://localhost:8000"
    oauth_frontend_url: str = "http://localhost:3000"
    meta_oauth_client_id: str | None = None
    meta_oauth_client_secret: str | None = None
    instagram_oauth_client_id: str | None = None
    instagram_oauth_client_secret: str | None = None
    threads_oauth_client_id: str | None = None
    threads_oauth_client_secret: str | None = None
    linkedin_oauth_client_id: str | None = None
    linkedin_oauth_client_secret: str | None = None
    youtube_oauth_client_id: str | None = None
    youtube_oauth_client_secret: str | None = None

    @property
    def use_secure_session_cookie(self) -> bool:
        """Use HTTPS-only cookies by default outside local development."""
        if self.session_cookie_secure is not None:
            return self.session_cookie_secure
        return self.env.lower() in {"staging", "production"}

    @model_validator(mode="after")
    def reject_development_secret_in_production(self) -> "Settings":
        insecure_secret = self.secret_key == DEFAULT_SECRET or self.secret_key.startswith(
            "replace-"
        )
        if self.env.lower() in {"production", "staging"} and insecure_secret:
            raise ValueError("AEVRA_SECRET_KEY must be changed outside development")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
