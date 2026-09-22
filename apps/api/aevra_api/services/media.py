from __future__ import annotations

import hashlib
import io
import tempfile
import uuid
from typing import Any, Literal, cast

from PIL import Image
from sqlalchemy.orm import Session

from aevra_api.config import Settings
from aevra_api.db.models import BrandProfile, MediaAsset
from aevra_api.domain.errors import (
    ForbiddenError,
    GenerationError,
    NotFoundError,
    ProviderUnavailableError,
)
from aevra_api.media.flux_provider import FluxHTTPProvider
from aevra_api.media.huggingface_provider import HuggingFaceImageProvider
from aevra_api.media.image_contracts import ImageGenerationRequest as ProviderImageRequest
from aevra_api.media.image_renderer import DeterministicImageProvider
from aevra_api.media.image_transforms import BrandVisualStyle, encode_image, resize_cover
from aevra_api.media.object_storage import ObjectStorage, build_object_storage
from aevra_api.media.storage import LocalMediaStorage
from aevra_api.media.video_composer import VideoComposer
from aevra_api.media.video_contracts import (
    FFmpegUnavailableError,
    VideoAspectRatio,
    VideoCompositionRequest,
    VideoSlide,
)
from aevra_api.repositories.media import MediaRepository
from aevra_api.repositories.tenancy import TenancyRepository
from aevra_api.schemas.media import ImageGenerateRequest, MediaAttachRequest, VideoComposeRequest
from aevra_api.services.brands import BrandService

MEDIA_EDIT_ROLES = {"owner", "admin", "member"}
PLATFORM_SIZES: dict[str, tuple[int, int, str]] = {
    "linkedin": (1200, 627, "1.91:1"),
    "instagram": (1080, 1350, "4:5"),
    "threads": (1080, 1080, "1:1"),
    "x": (1200, 675, "16:9"),
    "facebook": (1200, 630, "1.91:1"),
    "youtube": (1280, 720, "16:9"),
}


class MediaService:
    def __init__(
        self,
        session: Session,
        settings: Settings,
        image_provider: Any = None,
        video_composer: VideoComposer | None = None,
    ) -> None:
        self.session = session
        self.settings = settings
        self.repository = MediaRepository(session)
        self.tenancy_repository = TenancyRepository(session)
        self.storage = LocalMediaStorage(settings.media_root)
        self.object_storage: ObjectStorage | None = (
            build_object_storage(settings)
            if str(settings.storage_backend).lower() in {"minio", "s3", "s3-compatible"}
            else None
        )
        provider_name = settings.image_provider.lower()
        configured_provider: Any
        if provider_name == "huggingface":
            configured_provider = HuggingFaceImageProvider(
                settings.huggingface_api_token,
                settings.huggingface_image_model,
                provider=settings.huggingface_image_inference_provider,
                timeout_seconds=settings.huggingface_image_timeout_seconds,
            )
        elif provider_name == "flux":
            configured_provider = FluxHTTPProvider(settings.flux_base_url)
        else:
            configured_provider = DeterministicImageProvider()
        self.image_provider = image_provider or configured_provider
        self.video_composer = video_composer

    def _write(self, storage_key: str, content: bytes, content_type: str) -> None:
        if self.object_storage is not None:
            self.object_storage.put(storage_key, content, content_type)
        else:
            self.storage.write(storage_key, content)

    def _read(self, storage_key: str) -> bytes:
        if self.object_storage is not None:
            return self.object_storage.get(storage_key)
        return self.storage.read(storage_key)

    def _require_access(self, user_id: uuid.UUID, workspace_id: uuid.UUID) -> str:
        access = self.tenancy_repository.get_workspace_access(user_id, workspace_id)
        if access is None:
            raise NotFoundError("Workspace not found")
        return access[1]

    def _require_editor(self, user_id: uuid.UUID, workspace_id: uuid.UUID) -> None:
        if self._require_access(user_id, workspace_id) not in MEDIA_EDIT_ROLES:
            raise ForbiddenError("Media editor access is required")

    def _campaign(self, user_id: uuid.UUID, workspace_id: uuid.UUID, campaign_id: uuid.UUID):
        campaign = self.repository.get_campaign_for_user(user_id, workspace_id, campaign_id)
        if campaign is None:
            raise NotFoundError("Campaign not found")
        return campaign

    def upload_asset(
        self,
        user_id: uuid.UUID,
        workspace_id: uuid.UUID,
        campaign_id: uuid.UUID | None,
        filename: str,
        content_type: str,
        content: bytes,
    ) -> MediaAsset:
        """Persist a user-provided image/video through the configured storage adapter."""
        self._require_editor(user_id, workspace_id)
        campaign = self._campaign(user_id, workspace_id, campaign_id) if campaign_id else None
        normalized_type = content_type.lower().split(";", 1)[0]
        if normalized_type not in {
            "image/jpeg",
            "image/png",
            "image/webp",
            "video/mp4",
            "video/quicktime",
        }:
            raise GenerationError("Only JPEG, PNG, WebP, MP4, and MOV uploads are supported.")
        if not content:
            raise GenerationError("The uploaded file is empty.")
        if len(content) > 50 * 1024 * 1024:
            raise GenerationError("Uploads must be 50 MB or smaller.")
        media_type = "image" if normalized_type.startswith("image/") else "video"
        asset_id = uuid.uuid4()
        extension = (filename.rsplit(".", 1)[-1].lower() if "." in filename else "bin")[:8]
        storage_key = self.storage.key_for(workspace_id, asset_id, extension)
        self._write(storage_key, content, normalized_type)
        width = height = None
        if media_type == "image":
            try:
                with Image.open(io.BytesIO(content)) as image:
                    width, height = image.size
            except Exception as error:
                raise GenerationError("The uploaded image could not be decoded.") from error
        asset = MediaAsset(
            id=asset_id,
            workspace_id=workspace_id,
            campaign_id=campaign.id if campaign else None,
            created_by_user_id=user_id,
            media_type=media_type,
            asset_role="source",
            status="ready",
            storage_key=storage_key,
            filename=filename[:255],
            mime_type=normalized_type,
            bytes_size=len(content),
            sha256=hashlib.sha256(content).hexdigest(),
            width=width,
            height=height,
            generation_provider="upload",
            prompt=None,
            asset_metadata={"original_filename": filename, "content_type": normalized_type},
        )
        self.repository.add(asset)
        self.session.commit()
        return asset

    def attach_asset(
        self,
        user_id: uuid.UUID,
        workspace_id: uuid.UUID,
        asset_id: uuid.UUID,
        request: MediaAttachRequest,
    ) -> MediaAsset:
        self._require_editor(user_id, workspace_id)
        asset = self.repository.get_for_user(user_id, workspace_id, asset_id)
        if asset is None:
            raise NotFoundError("Media asset not found")
        campaign = self._campaign(user_id, workspace_id, request.campaign_id)
        asset.campaign_id = campaign.id
        self.session.commit()
        return asset

    @staticmethod
    def _brand_style(
        brand: BrandProfile | None, request: ImageGenerateRequest
    ) -> BrandVisualStyle | None:
        if not request.brand_overlay:
            return None
        label = request.brand_text or (brand.name if brand else None)
        return BrandVisualStyle(label=label[:80]) if label else None

    def generate_images(
        self, user_id: uuid.UUID, workspace_id: uuid.UUID, request: ImageGenerateRequest
    ) -> list[MediaAsset]:
        self._require_editor(user_id, workspace_id)
        campaign = (
            self._campaign(user_id, workspace_id, request.campaign_id)
            if request.campaign_id
            else None
        )
        brand = (
            BrandService(self.session).get_brand(user_id, workspace_id, campaign.brand_id)
            if campaign
            else None
        )
        provider_request = ProviderImageRequest(
            prompt=request.prompt,
            width=1024,
            height=1024,
            seed=request.seed,
            negative_prompt=request.negative_prompt or "",
            style="editorial",
            output_format="png",
        )
        try:
            result = self.image_provider.generate(
                provider_request, brand_style=self._brand_style(brand, request)
            )
        except Exception as error:
            if isinstance(error, (GenerationError, ProviderUnavailableError)):
                raise
            raise GenerationError(f"Image generation failed: {error}") from error

        source_id = uuid.uuid4()
        source_key = self.storage.key_for(workspace_id, source_id, result.image.file_extension)
        self._write(source_key, result.image.data, result.image.content_type)
        source = MediaAsset(
            id=source_id,
            workspace_id=workspace_id,
            campaign_id=campaign.id if campaign else None,
            created_by_user_id=user_id,
            media_type="image",
            asset_role="generated",
            status="ready",
            storage_key=source_key,
            filename=f"aevra-{source_id}.png",
            mime_type=result.image.content_type,
            bytes_size=len(result.image.data),
            sha256=result.image.sha256,
            width=result.image.width,
            height=result.image.height,
            generation_provider=f"{result.provider}/{result.model}",
            prompt=request.prompt,
            asset_metadata={"seed": result.seed, **result.metadata},
        )
        assets = [source]
        with Image.open(io.BytesIO(result.image.data)) as opened:
            image = opened.convert("RGBA")
            for platform in request.platforms:
                width, height, ratio = PLATFORM_SIZES[platform]
                transformed = resize_cover(image, width, height)
                encoded = encode_image(transformed, "png")
                asset_id = uuid.uuid4()
                storage_key = self.storage.key_for(workspace_id, asset_id, encoded.file_extension)
                self._write(storage_key, encoded.data, encoded.content_type)
                assets.append(
                    MediaAsset(
                        id=asset_id,
                        workspace_id=workspace_id,
                        campaign_id=campaign.id if campaign else None,
                        created_by_user_id=user_id,
                        parent_asset_id=source_id,
                        media_type="image",
                        asset_role="variant",
                        platform=platform,
                        status="ready",
                        storage_key=storage_key,
                        filename=f"aevra-{platform}-{asset_id}.png",
                        mime_type=encoded.content_type,
                        bytes_size=len(encoded.data),
                        sha256=encoded.sha256,
                        width=encoded.width,
                        height=encoded.height,
                        generation_provider=f"{result.provider}/{result.model}",
                        prompt=request.prompt,
                        asset_metadata={
                            "platform": platform,
                            "aspect_ratio": ratio,
                            "source_asset_id": str(source_id),
                        },
                    )
                )
        self.repository.add_many(assets)
        self.session.commit()
        return assets

    def list_assets(
        self,
        user_id: uuid.UUID,
        workspace_id: uuid.UUID,
        campaign_id: uuid.UUID | None = None,
        media_type: str | None = None,
    ) -> list[MediaAsset]:
        self._require_access(user_id, workspace_id)
        return self.repository.list_for_user(user_id, workspace_id, campaign_id, media_type)

    def get_asset(
        self, user_id: uuid.UUID, workspace_id: uuid.UUID, asset_id: uuid.UUID
    ) -> MediaAsset:
        self._require_access(user_id, workspace_id)
        asset = self.repository.get_for_user(user_id, workspace_id, asset_id)
        if asset is None:
            raise NotFoundError("Media asset not found")
        return asset

    def asset_bytes(
        self, user_id: uuid.UUID, workspace_id: uuid.UUID, asset_id: uuid.UUID
    ) -> tuple[MediaAsset, bytes]:
        asset = self.get_asset(user_id, workspace_id, asset_id)
        try:
            return asset, self._read(asset.storage_key)
        except (FileNotFoundError, OSError) as error:
            raise NotFoundError("Media asset file is unavailable") from error

    def compose_videos(
        self, user_id: uuid.UUID, workspace_id: uuid.UUID, request: VideoComposeRequest
    ) -> list[MediaAsset]:
        self._require_editor(user_id, workspace_id)
        campaign = (
            self._campaign(user_id, workspace_id, request.campaign_id)
            if request.campaign_id
            else None
        )
        source_assets = [
            self.get_asset(user_id, workspace_id, asset_id) for asset_id in request.source_asset_ids
        ]
        if any(
            (campaign is not None and asset.campaign_id not in {None, campaign.id})
            or asset.media_type != "image"
            or asset.status != "ready"
            for asset in source_assets
        ):
            raise NotFoundError("One or more source image assets were not found")
        duration = request.duration_seconds or self.settings.video_default_seconds
        duration = min(duration, self.settings.video_max_seconds, 180.0)
        composer_mode = self.settings.video_provider
        assets: list[MediaAsset] = []
        with tempfile.TemporaryDirectory(prefix="aevra-video-source-") as source_directory:
            source_paths = []
            for source in source_assets:
                source_path = __import__("pathlib").Path(source_directory) / source.filename
                source_path.write_bytes(self._read(source.storage_key))
                source_paths.append(source_path)
            per_slide = min(30.0, max(0.5, duration / len(source_paths)))
            for aspect_ratio in request.aspect_ratios:
                with tempfile.TemporaryDirectory(prefix="aevra-video-") as temporary_directory:
                    composer = self.video_composer or VideoComposer(
                        temporary_directory,
                        execution_mode=cast(
                            Literal["auto", "ffmpeg", "mock"],
                            composer_mode
                            if composer_mode in {"auto", "ffmpeg", "mock"}
                            else "auto",
                        ),
                        ffmpeg_binary=self.settings.ffmpeg_binary,
                    )
                    video_request = VideoCompositionRequest(
                        slides=tuple(VideoSlide(path, per_slide) for path in source_paths),
                        aspect_ratio=VideoAspectRatio(aspect_ratio),
                        fps=self.settings.video_fps,
                        output_stem=(
                            f"media-{campaign.id if campaign else uuid.uuid4()}-"
                            f"{aspect_ratio.replace(':', '-')}"
                        ),
                    )
                    try:
                        result = composer.compose(video_request)
                    except FFmpegUnavailableError as error:
                        raise ProviderUnavailableError(str(error)) from error
                    except Exception as error:
                        raise GenerationError(f"Video composition failed: {error}") from error
                    content = result.output_path.read_bytes()
                asset_id = uuid.uuid4()
                extension = "mp4" if result.mode == "ffmpeg" else "json"
                storage_key = self.storage.key_for(workspace_id, asset_id, extension)
                self._write(
                    storage_key,
                    content,
                    "video/mp4" if result.mode == "ffmpeg" else "application/json",
                )
                canvas = result.canvas
                assets.append(
                    MediaAsset(
                        id=asset_id,
                        workspace_id=workspace_id,
                        campaign_id=campaign.id if campaign else None,
                        created_by_user_id=user_id,
                        parent_asset_id=source_assets[0].id,
                        media_type="video",
                        asset_role="composition",
                        platform=None,
                        status="ready",
                        storage_key=storage_key,
                        filename=f"{video_request.output_stem}.{extension}",
                        mime_type="video/mp4" if result.mode == "ffmpeg" else "application/json",
                        bytes_size=len(content),
                        sha256=__import__("hashlib").sha256(content).hexdigest(),
                        width=canvas.width,
                        height=canvas.height,
                        duration_seconds=result.duration_seconds,
                        generation_provider=result.mode,
                        prompt=request.caption,
                        asset_metadata={
                            "aspect_ratio": aspect_ratio,
                            "render_key": result.render_key,
                            "manifest": result.manifest,
                            "caption": request.caption,
                        },
                    )
                )
        self.repository.add_many(assets)
        self.session.commit()
        return assets
