import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

Platform = Literal["linkedin", "instagram", "threads", "x", "facebook", "youtube"]


class SocialAccountCreateRequest(BaseModel):
    platform: Platform
    external_account_id: str = Field(min_length=2, max_length=300)
    display_name: str = Field(min_length=1, max_length=200)
    access_token_ref: str = Field(min_length=4, max_length=1400)
    capabilities: list[str] = Field(default_factory=list, max_length=30)


class SocialAccountResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    workspace_id: uuid.UUID
    platform: Platform
    external_account_id: str
    display_name: str
    status: Literal["connected", "paused", "revoked"]
    capabilities: list[str]
    granted_scopes: list[str]
    access_token_expires_at: datetime | None
    last_verified_at: datetime | None
    created_at: datetime
    updated_at: datetime


class PublishRequest(BaseModel):
    campaign_id: uuid.UUID | None = None
    social_account_id: uuid.UUID
    idempotency_key: str = Field(min_length=8, max_length=160)
    text: str = Field(min_length=1, max_length=30_000)
    media_urls: list[str] = Field(default_factory=list, max_length=4)


class PublishJobResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    workspace_id: uuid.UUID
    campaign_id: uuid.UUID | None
    social_account_id: uuid.UUID
    idempotency_key: str
    status: Literal["queued", "publishing", "published", "verified", "failed", "cancelled"]
    payload: dict[str, object]
    external_post_id: str | None
    external_url: str | None
    attempts: int
    retryable: bool
    error_message: str | None
    published_at: datetime | None
    verified_at: datetime | None
    created_at: datetime
    updated_at: datetime
