import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from aevra_api.schemas.campaigns import Platform

ImageAspectRatio = Literal["1:1", "4:5", "1.91:1", "16:9", "9:16"]
VideoAspectRatio = Literal["9:16", "1:1", "16:9"]
MediaType = Literal["image", "video"]
MediaStatus = Literal["processing", "ready", "failed"]
MediaRole = Literal["source", "generated", "variant", "composition"]


def default_image_platforms() -> list[Platform]:
    return ["instagram"]


def default_video_ratios() -> list[VideoAspectRatio]:
    return ["9:16", "1:1", "16:9"]


class ImageGenerateRequest(BaseModel):
    campaign_id: uuid.UUID | None = None
    prompt: str = Field(min_length=3, max_length=4000)
    platforms: list[Platform] = Field(
        default_factory=default_image_platforms, min_length=1, max_length=6
    )
    aspect_ratio: ImageAspectRatio = "1:1"
    brand_overlay: bool = True
    brand_text: str | None = Field(default=None, max_length=120)
    negative_prompt: str | None = Field(default=None, max_length=2000)
    seed: int | None = Field(default=None, ge=0, le=4_294_967_295)

    @field_validator("platforms")
    @classmethod
    def unique_platforms(cls, values: list[Platform]) -> list[Platform]:
        return list(dict.fromkeys(values))


class VideoComposeRequest(BaseModel):
    campaign_id: uuid.UUID | None = None
    source_asset_ids: list[uuid.UUID] = Field(min_length=1, max_length=8)
    aspect_ratios: list[VideoAspectRatio] = Field(
        default_factory=default_video_ratios, min_length=1, max_length=3
    )
    duration_seconds: float | None = Field(default=None, ge=0.5, le=300)
    title: str | None = Field(default=None, max_length=200)
    caption: str | None = Field(default=None, max_length=500)

    @field_validator("source_asset_ids", "aspect_ratios")
    @classmethod
    def unique_values(cls, values: list[object]) -> list[object]:
        return list(dict.fromkeys(values))


class MediaAssetResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    workspace_id: uuid.UUID
    campaign_id: uuid.UUID | None
    created_by_user_id: uuid.UUID
    parent_asset_id: uuid.UUID | None
    media_type: MediaType
    asset_role: MediaRole
    platform: Platform | None
    status: MediaStatus
    storage_key: str
    filename: str
    mime_type: str
    bytes_size: int
    sha256: str
    width: int | None
    height: int | None
    duration_seconds: float | None
    generation_provider: str | None
    prompt: str | None
    asset_metadata: dict[str, object]
    error_message: str | None
    created_at: datetime
    updated_at: datetime
    download_url: str | None = None


class MediaGenerationResponse(BaseModel):
    assets: list[MediaAssetResponse]


class MediaAttachRequest(BaseModel):
    campaign_id: uuid.UUID
