import hmac
import mimetypes
import time
import uuid
from typing import Literal
from urllib.parse import quote

from fastapi import APIRouter, File, HTTPException, Response, UploadFile, status
from starlette.concurrency import run_in_threadpool

from aevra_api.api.dependencies import CurrentUser, SessionDep, SettingsDep
from aevra_api.db.models import MediaAsset
from aevra_api.domain.errors import UnsupportedContentError
from aevra_api.knowledge.normalization import extract_pdf_text, normalize_text
from aevra_api.schemas.media import (
    AssetCaptionRequest,
    ImageGenerateRequest,
    MediaAssetResponse,
    MediaAttachRequest,
    MediaGenerationResponse,
    VideoComposeRequest,
)
from aevra_api.services.media import MediaService
from aevra_api.services.media_delivery import signature as delivery_signature

router = APIRouter(prefix="/workspaces/{workspace_id}/media", tags=["media"])


def _response(asset: object, workspace_id: uuid.UUID) -> MediaAssetResponse:
    response = MediaAssetResponse.model_validate(asset)
    response.download_url = f"/api/v1/workspaces/{workspace_id}/media/assets/{response.id}/download"
    return response


@router.post(
    "/assets/upload", response_model=MediaAssetResponse, status_code=status.HTTP_201_CREATED
)
async def upload_asset(
    workspace_id: uuid.UUID,
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
    campaign_id: uuid.UUID | None = None,
    file: UploadFile = File(...),  # noqa: B008 - FastAPI declares uploads this way.
) -> MediaAssetResponse:
    content = await file.read()
    asset = MediaService(session, settings).upload_asset(
        current_user.id,
        workspace_id,
        campaign_id,
        file.filename or "upload",
        file.content_type
        or (mimetypes.guess_type(file.filename or "")[0] or "application/octet-stream"),
        content,
    )
    return _response(asset, workspace_id)


@router.post("/assets/{asset_id}/attach", response_model=MediaAssetResponse)
def attach_asset(
    workspace_id: uuid.UUID,
    asset_id: uuid.UUID,
    request: MediaAttachRequest,
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
) -> MediaAssetResponse:
    asset = MediaService(session, settings).attach_asset(
        current_user.id, workspace_id, asset_id, request
    )
    return _response(asset, workspace_id)


@router.post(
    "/images/generate",
    response_model=MediaGenerationResponse,
    status_code=status.HTTP_201_CREATED,
)
def generate_images(
    workspace_id: uuid.UUID,
    request: ImageGenerateRequest,
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
) -> MediaGenerationResponse:
    assets = MediaService(session, settings).generate_images(current_user.id, workspace_id, request)
    return MediaGenerationResponse(assets=[_response(asset, workspace_id) for asset in assets])


@router.post(
    "/videos/compose",
    response_model=MediaGenerationResponse,
    status_code=status.HTTP_201_CREATED,
)
def compose_videos(
    workspace_id: uuid.UUID,
    request: VideoComposeRequest,
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
) -> MediaGenerationResponse:
    assets = MediaService(session, settings).compose_videos(current_user.id, workspace_id, request)
    return MediaGenerationResponse(assets=[_response(asset, workspace_id) for asset in assets])


@router.get("/assets", response_model=list[MediaAssetResponse])
def list_assets(
    workspace_id: uuid.UUID,
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
    campaign_id: uuid.UUID | None = None,
    media_type: Literal["image", "video"] | None = None,
) -> list[MediaAssetResponse]:
    assets = MediaService(session, settings).list_assets(
        current_user.id, workspace_id, campaign_id, media_type
    )
    return [_response(asset, workspace_id) for asset in assets]


@router.get("/assets/{asset_id}", response_model=MediaAssetResponse)
def get_asset(
    workspace_id: uuid.UUID,
    asset_id: uuid.UUID,
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
) -> MediaAssetResponse:
    asset = MediaService(session, settings).get_asset(current_user.id, workspace_id, asset_id)
    return _response(asset, workspace_id)


@router.get("/assets/{asset_id}/download")
def download_asset(
    workspace_id: uuid.UUID,
    asset_id: uuid.UUID,
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
) -> Response:
    asset, content = MediaService(session, settings).asset_bytes(
        current_user.id, workspace_id, asset_id
    )
    return Response(
        content=content,
        media_type=asset.mime_type,
        headers={"Content-Disposition": f"inline; filename*=UTF-8''{quote(asset.filename)}"},
    )


@router.patch("/assets/{asset_id}/caption", response_model=MediaAssetResponse)
def save_caption(
    workspace_id: uuid.UUID,
    asset_id: uuid.UUID,
    request: AssetCaptionRequest,
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
):
    return _response(
        MediaService(session, settings).save_caption(
            current_user.id, workspace_id, asset_id, request.caption
        ),
        workspace_id,
    )


@router.post("/captions/extract")
async def extract_caption(
    workspace_id: uuid.UUID,
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
    file: UploadFile = File(...),  # noqa: B008
):
    MediaService(session, settings)._require_editor(current_user.id, workspace_id)
    content = await file.read(2 * 1024 * 1024 + 1)
    if len(content) > 2 * 1024 * 1024:
        raise UnsupportedContentError("Caption files must be 2 MB or smaller.")
    extension = (file.filename or "").lower().rsplit(".", 1)[-1]
    if extension == "pdf":
        text = await run_in_threadpool(extract_pdf_text, content, 20)
    elif extension in {"txt", "md"}:
        try:
            text = normalize_text(content.decode("utf-8-sig"), "text")
        except UnicodeDecodeError as error:
            raise UnsupportedContentError("Save the text file as UTF-8.") from error
    else:
        raise UnsupportedContentError("Choose a PDF, TXT, or Markdown file.")
    if len(text) > 30000:
        raise UnsupportedContentError(
            "Extracted caption exceeds 30,000 characters. Upload a shorter file."
        )
    return {"text": text, "filename": file.filename}


@router.get("/delivery/{asset_id}.{extension}")
def deliver_asset(
    workspace_id: uuid.UUID,
    asset_id: uuid.UUID,
    extension: str,
    expires: int,
    signature: str,
    session: SessionDep,
    settings: SettingsDep,
):
    now = int(time.time())
    expected = delivery_signature(settings.secret_key, workspace_id, asset_id, expires)
    if expires <= now or expires > now + 3600 or not hmac.compare_digest(signature, expected):
        raise HTTPException(403, "Delivery link is invalid or expired")
    asset = session.get(MediaAsset, asset_id)
    if asset is None or asset.workspace_id != workspace_id or asset.status != "ready":
        raise HTTPException(404, "Media not found")
    content = MediaService(session, settings)._read(asset.storage_key)
    return Response(
        content,
        media_type=asset.mime_type,
        headers={"Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff"},
    )
