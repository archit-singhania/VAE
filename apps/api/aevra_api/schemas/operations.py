import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class ScheduleCreateRequest(BaseModel):
    campaign_id: uuid.UUID | None = None
    social_account_id: uuid.UUID
    idempotency_key: str = Field(min_length=8, max_length=160)
    scheduled_for: datetime
    text: str = Field(min_length=1, max_length=30_000)
    media_urls: list[str] = Field(default_factory=list, max_length=4)


class ScheduleRescheduleRequest(BaseModel):
    scheduled_for: datetime


class ScheduledPostResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    workspace_id: uuid.UUID
    campaign_id: uuid.UUID | None
    social_account_id: uuid.UUID
    idempotency_key: str
    scheduled_for: datetime
    status: Literal["scheduled", "processing", "published", "failed", "cancelled"]
    payload: dict[str, object]
    attempts: int
    error_message: str | None
    published_job_id: uuid.UUID | None
    created_at: datetime
    updated_at: datetime


class MetricsCreateRequest(BaseModel):
    social_account_id: uuid.UUID
    external_post_id: str = Field(min_length=1, max_length=300)
    collected_at: datetime
    impressions: int = Field(default=0, ge=0)
    engagements: int = Field(default=0, ge=0)
    clicks: int = Field(default=0, ge=0)
    likes: int = Field(default=0, ge=0)
    comments: int = Field(default=0, ge=0)
    shares: int = Field(default=0, ge=0)
    metric_metadata: dict[str, object] = Field(default_factory=dict)


class MetricsResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    workspace_id: uuid.UUID
    social_account_id: uuid.UUID
    external_post_id: str
    collected_at: datetime
    impressions: int
    engagements: int
    clicks: int
    likes: int
    comments: int
    shares: int
    metric_metadata: dict[str, object]
    created_at: datetime


class AuditLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    workspace_id: uuid.UUID
    actor_user_id: uuid.UUID | None
    action: str
    resource_type: str
    resource_id: str | None
    request_id: str | None
    details: dict[str, object]
    created_at: datetime
