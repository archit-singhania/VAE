"""Short-lived, asset-bound delivery links minted at dispatch (never at scheduling)."""

import hashlib
import hmac
import re
import time
import uuid
from urllib.parse import urlsplit

from aevra_api.publishing.contracts import PublisherError
from aevra_api.services.media import MediaService


def signature(secret: str, workspace_id: uuid.UUID, asset_id: uuid.UUID, expires: int) -> str:
    message = f"publish-media:{workspace_id}:{asset_id}:{expires}".encode()
    return hmac.new(secret.encode(), message, hashlib.sha256).hexdigest()


def delivery_urls(session, settings, user_id, workspace_id, urls):
    result = []
    for url in urls:
        parsed = urlsplit(url)
        match = re.fullmatch(
            r"/api/v1/workspaces/([0-9a-f-]+)/media/assets/([0-9a-f-]+)/download", parsed.path
        )
        if not match:
            if parsed.scheme not in {"https", "http"} or not parsed.netloc:
                raise PublisherError(
                    "Media URL must be a workspace asset or an absolute HTTP(S) URL.",
                    retryable=False,
                )
            result.append(url)
            continue
        if match[1] != str(workspace_id):
            raise PublisherError("Media belongs to another workspace.", retryable=False)
        service = MediaService(session, settings)
        asset = service.get_asset(user_id, workspace_id, uuid.UUID(match[2]))
        if asset.status != "ready":
            raise PublisherError("Selected media is not ready.", retryable=False)
        base = settings.public_api_base_url.rstrip("/")
        if not base and service.object_storage is not None:
            signed = service.object_storage.signed_url(asset.storage_key, 3600)
            parsed_signed = urlsplit(signed)
            if parsed_signed.scheme == "https" and "." in (parsed_signed.hostname or ""):
                result.append(signed)
                continue
        if not base.startswith("https://"):
            raise PublisherError(
                "Configure AEVRA_PUBLIC_API_BASE_URL with the public HTTPS API origin "
                "to deliver local media.",
                retryable=False,
            )
        expires = int(time.time()) + 3600
        sig = signature(settings.secret_key, workspace_id, asset.id, expires)
        extension = (
            ".mp4"
            if asset.mime_type == "video/mp4"
            else ".mov"
            if asset.mime_type == "video/quicktime"
            else ".png"
        )
        result.append(
            f"{base}/api/v1/workspaces/{workspace_id}/media/delivery/{asset.id}{extension}"
            f"?expires={expires}&signature={sig}"
        )
    return result
