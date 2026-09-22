"""Provider OAuth handshakes.

The callback is deliberately small and provider-neutral: it validates a signed,
workspace-bound state, exchanges the one-time code server-side, encrypts the
provider token through the existing vault, and stores only the account metadata.
Provider app review and credentials are still required before these routes can
be used against live accounts.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from hashlib import sha256
from typing import Literal, cast
from urllib.parse import urlencode

import httpx
from fastapi import APIRouter, HTTPException, Query, status
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from sqlalchemy import select

from aevra_api.api.dependencies import CurrentUser, SessionDep, SettingsDep
from aevra_api.config import Settings
from aevra_api.db.models import OAuthState
from aevra_api.domain.errors import AuthenticationError, ConflictError, ProviderUnavailableError
from aevra_api.schemas.publishing import Platform, SocialAccountCreateRequest
from aevra_api.security import create_oauth_state, decode_oauth_state
from aevra_api.services.publishing import PublishingService
from aevra_api.services.tenancy import TenancyService

router = APIRouter(prefix="/workspaces/{workspace_id}/publishing/oauth", tags=["oauth"])
callback_router = APIRouter(prefix="/oauth", tags=["oauth"])


@dataclass(frozen=True)
class ProviderConfig:
    client_id: str | None
    client_secret: str | None
    authorize_url: str
    token_url: str
    profile_url: str
    scopes: tuple[str, ...]
    refresh_supported: bool = False
    revoke_url: str | None = None


class OAuthAuthorizeResponse(BaseModel):
    provider: Platform
    authorization_url: str
    expires_in: int


def provider_config(provider: str, settings: Settings) -> ProviderConfig:
    if provider == "instagram":
        return ProviderConfig(
            settings.instagram_oauth_client_id or settings.meta_oauth_client_id,
            settings.instagram_oauth_client_secret or settings.meta_oauth_client_secret,
            "https://www.instagram.com/oauth/authorize",
            "https://api.instagram.com/oauth/access_token",
            "https://graph.instagram.com/me?fields=user_id,username",
            ("instagram_business_basic", "instagram_business_content_publish"),
            False,
            "https://graph.instagram.com/me/permissions",
        )
    if provider == "facebook":
        return ProviderConfig(
            (
                settings.instagram_oauth_client_id
                if provider == "instagram" and settings.instagram_oauth_client_id
                else settings.meta_oauth_client_id
            ),
            (
                settings.instagram_oauth_client_secret
                if provider == "instagram" and settings.instagram_oauth_client_secret
                else settings.meta_oauth_client_secret
            ),
            "https://www.facebook.com/v23.0/dialog/oauth",
            "https://graph.facebook.com/v23.0/oauth/access_token",
            "https://graph.facebook.com/v23.0/me?fields=id,name,username",
            (
                "public_profile",
                "pages_show_list",
                "pages_read_engagement",
                "pages_manage_posts",
                "instagram_basic",
                "instagram_content_publish",
            ),
            False,
            "https://graph.facebook.com/v23.0/me/permissions",
        )
    if provider == "threads":
        return ProviderConfig(
            settings.threads_oauth_client_id or settings.meta_oauth_client_id,
            settings.threads_oauth_client_secret or settings.meta_oauth_client_secret,
            "https://threads.net/oauth/authorize",
            "https://graph.threads.net/oauth/access_token",
            "https://graph.threads.net/v1.0/me?fields=id,name,username",
            ("threads_basic", "threads_content_publish"),
            True,
            "https://graph.threads.net/v1.0/me/permissions",
        )
    if provider == "linkedin":
        return ProviderConfig(
            settings.linkedin_oauth_client_id,
            settings.linkedin_oauth_client_secret,
            "https://www.linkedin.com/oauth/v2/authorization",
            "https://www.linkedin.com/oauth/v2/accessToken",
            "https://api.linkedin.com/v2/userinfo",
            ("openid", "profile", "email", "w_member_social"),
            True,
            "https://www.linkedin.com/oauth/v2/revoke",
        )
    if provider == "youtube":
        return ProviderConfig(
            settings.youtube_oauth_client_id,
            settings.youtube_oauth_client_secret,
            "https://accounts.google.com/o/oauth2/v2/auth",
            "https://oauth2.googleapis.com/token",
            "https://www.googleapis.com/youtube/v3/channels",
            (
                "openid",
                "email",
                "profile",
                "https://www.googleapis.com/auth/youtube.upload",
                "https://www.googleapis.com/auth/youtube.readonly",
            ),
            True,
            "https://oauth2.googleapis.com/revoke",
        )
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unsupported OAuth provider")


def redirect_uri(provider: str, settings: Settings) -> str:
    """Return one stable callback URL per provider for app-review allowlists."""
    return f"{settings.oauth_redirect_base_url.rstrip('/')}/api/v1/oauth/{provider}/callback"


def frontend_redirect(settings: Settings, **params: str) -> RedirectResponse:
    query = urlencode(params)
    return RedirectResponse(f"{settings.oauth_frontend_url.rstrip('/')}/?{query}", status_code=303)


def _hash_nonce(nonce: str) -> str:
    return sha256(nonce.encode("utf-8")).hexdigest()


def _consume_state(session, state_data: dict[str, str]) -> None:
    record = session.scalar(
        select(OAuthState)
        .where(
            OAuthState.nonce_hash == _hash_nonce(state_data["nonce"]),
            OAuthState.consumed_at.is_(None),
            OAuthState.expires_at > datetime.now(UTC),
        )
        .with_for_update()
    )
    if record is None:
        raise AuthenticationError("OAuth state was already used or has expired")
    if (
        str(record.user_id) != state_data["user_id"]
        or str(record.workspace_id) != state_data["workspace_id"]
        or record.provider != state_data["provider"]
    ):
        raise AuthenticationError("OAuth state does not match the requested connection")
    record.consumed_at = datetime.now(UTC)
    session.commit()


def _expires_at(payload: dict[str, object]) -> datetime | None:
    raw = payload.get("expires_in")
    try:
        seconds = int(raw) if isinstance(raw, (str, int, float)) else 0
    except (TypeError, ValueError):
        seconds = 0
    return datetime.now(UTC) + timedelta(seconds=seconds) if seconds > 0 else None


def _scopes(payload: dict[str, object], requested: tuple[str, ...]) -> list[str]:
    raw = payload.get("scope")
    if isinstance(raw, str):
        return [item for item in raw.split() if item]
    if isinstance(raw, list):
        return [str(item) for item in raw]
    return list(requested)


async def _resolve_meta_account(
    client: httpx.AsyncClient,
    provider: str,
    access_token: str,
    profile: dict[str, object],
) -> tuple[str, str, str, dict[str, object]]:
    """Resolve a publishable Page/Instagram identity from a Meta user token."""
    if provider != "facebook":
        external_id, display_name = profile_identity(provider, profile)
        return external_id, display_name, access_token, {}
    response = await client.get(
        "https://graph.facebook.com/v23.0/me/accounts",
        params={
            "fields": "id,name,access_token,instagram_business_account{id,username}",
        },
        headers={"Authorization": f"Bearer {access_token}"},
    )
    response.raise_for_status()
    pages = response.json().get("data", [])
    if not isinstance(pages, list):
        pages = []
    for page in pages:
        if not isinstance(page, dict):
            continue
        page_token = str(page.get("access_token", ""))
        page_id = str(page.get("id", ""))
        page_name = str(page.get("name", "Facebook Page"))
        instagram = page.get("instagram_business_account")
        if provider == "instagram":
            if not isinstance(instagram, dict) or not instagram.get("id"):
                continue
            instagram_id = str(instagram["id"])
            return (
                instagram_id,
                str(instagram.get("username") or page_name),
                page_token or access_token,
                {"page_id": page_id, "page_name": page_name},
            )
        if page_id:
            return (
                page_id,
                page_name,
                page_token or access_token,
                {
                    "page_id": page_id,
                    "page_name": page_name,
                    "instagram_business_account_id": (
                        str(instagram.get("id"))
                        if isinstance(instagram, dict) and instagram.get("id")
                        else None
                    ),
                },
            )
    raise ProviderUnavailableError(
        "Connect a Facebook Page (and an Instagram Business account for Instagram publishing)"
    )


@router.get("/{provider}/authorize", response_model=OAuthAuthorizeResponse)
def authorize(
    workspace_id: uuid.UUID,
    provider: Literal["facebook", "instagram", "threads", "linkedin", "youtube"],
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
) -> OAuthAuthorizeResponse:
    TenancyService(session).get_workspace(current_user.id, workspace_id)
    config = provider_config(provider, settings)
    if not config.client_id or not config.client_secret:
        raise ProviderUnavailableError(
            f"{provider.title()} OAuth credentials are not configured on this environment"
        )
    state = create_oauth_state(current_user.id, workspace_id, provider, settings)
    state_data = decode_oauth_state(state, settings)
    session.add(
        OAuthState(
            nonce_hash=_hash_nonce(state_data["nonce"]),
            user_id=current_user.id,
            workspace_id=workspace_id,
            provider=provider,
            expires_at=datetime.now(UTC) + timedelta(minutes=settings.oauth_state_minutes),
        )
    )
    session.commit()
    uri = redirect_uri(provider, settings)
    query = {
        "client_id": config.client_id,
        "redirect_uri": uri,
        "response_type": "code",
        "scope": (
            ",".join(config.scopes) if provider == "instagram" else " ".join(config.scopes)
        ),
        "state": state,
    }
    if provider == "youtube":
        query.update({"access_type": "offline", "prompt": "consent"})
    return OAuthAuthorizeResponse(
        provider=provider,
        authorization_url=f"{config.authorize_url}?{urlencode(query)}",
        expires_in=settings.oauth_state_minutes * 60,
    )


@callback_router.get("/{provider}/callback")
async def callback(
    provider: Literal["facebook", "instagram", "threads", "linkedin", "youtube"],
    settings: SettingsDep,
    session: SessionDep,
    code: str | None = Query(default=None),
    state: str | None = Query(default=None),
    error: str | None = Query(default=None),
) -> RedirectResponse:
    if not state:
        return frontend_redirect(
            settings, oauth="error", provider=provider, message="Missing OAuth code"
        )
    try:
        state_data = decode_oauth_state(state, settings)
        if state_data["provider"] != provider:
            raise ProviderUnavailableError("OAuth state does not match this workspace")
        _consume_state(session, state_data)
        if error:
            return frontend_redirect(
                settings, oauth="error", provider=provider, message="Provider denied access"
            )
        if not code:
            return frontend_redirect(
                settings, oauth="error", provider=provider, message="Missing OAuth code"
            )
        user_id = uuid.UUID(state_data["user_id"])
        workspace_id = uuid.UUID(state_data["workspace_id"])
        TenancyService(session).require_user(user_id)
        config = provider_config(provider, settings)
        if not config.client_id or not config.client_secret:
            raise ProviderUnavailableError("OAuth credentials are not configured")
        uri = redirect_uri(provider, settings)
        async with httpx.AsyncClient(timeout=20) as client:
            token_response = await client.post(
                config.token_url,
                data={
                    "client_id": config.client_id,
                    "client_secret": config.client_secret,
                    "redirect_uri": uri,
                    "code": code,
                    "grant_type": "authorization_code",
                },
            )
            token_response.raise_for_status()
            token_payload = token_response.json()
            access_token = str(token_payload.get("access_token", ""))
            if not access_token:
                raise ProviderUnavailableError("Provider returned no access token")
            profile_params = {"part": "snippet", "mine": "true"} if provider == "youtube" else None
            profile_response = await client.get(
                config.profile_url,
                params=profile_params,
                headers={"Authorization": f"Bearer {access_token}"},
            )
            profile_response.raise_for_status()
            profile = profile_response.json()
            external_id, display_name, access_token, account_metadata = await _resolve_meta_account(
                client, provider, access_token, profile
            )
        # Persist the access/refresh pair only through the encrypted credential path.
        account = PublishingService(session, settings).connect_credentials(
            user_id,
            workspace_id,
            SocialAccountCreateRequest(
                platform=provider,
                external_account_id=external_id,
                display_name=display_name,
                access_token_ref=access_token,
                capabilities=["publish", "analytics"],
            ),
            refresh_token=str(token_payload.get("refresh_token"))
            if token_payload.get("refresh_token")
            else None,
            expires_at=_expires_at(token_payload),
            granted_scopes=_scopes(token_payload, config.scopes),
            account_metadata=account_metadata,
        )
        return frontend_redirect(
            settings, oauth="connected", provider=provider, account=str(account.id)
        )
    except (
        httpx.HTTPError,
        KeyError,
        ValueError,
        AuthenticationError,
        ProviderUnavailableError,
    ):
        # Provider responses can echo request details; keep those out of the
        # browser redirect and rely on request-id/server logs for diagnosis.
        return frontend_redirect(
            settings, oauth="error", provider=provider, message="OAuth connection failed"
        )


@router.post("/{provider}/accounts/{account_id}/refresh", response_model=dict[str, object])
async def refresh(
    workspace_id: uuid.UUID,
    account_id: uuid.UUID,
    provider: Literal["facebook", "instagram", "threads", "linkedin", "youtube"],
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
) -> dict[str, object]:
    config = provider_config(provider, settings)
    if not config.refresh_supported:
        raise ConflictError(f"{provider.title()} does not expose a standard refresh flow")
    service = PublishingService(session, settings)
    account = service.account(current_user.id, workspace_id, account_id)
    if account.platform != provider:
        raise ConflictError("Provider does not match the connected account")
    access_token, refresh_token = service.token_pair(account)
    if provider == "threads":
        refresh_token = access_token
    if not refresh_token:
        raise ConflictError("No refresh token is stored for this account")
    async with httpx.AsyncClient(timeout=20) as client:
        if provider == "threads":
            response = await client.get(
                "https://graph.threads.net/refresh_access_token",
                params={"grant_type": "th_refresh_token", "access_token": refresh_token},
            )
        else:
            response = await client.post(
                config.token_url,
                data={
                    "client_id": config.client_id,
                    "client_secret": config.client_secret,
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token,
                },
            )
        response.raise_for_status()
        payload = response.json()
    access_token = str(payload.get("access_token", ""))
    if not access_token:
        raise ProviderUnavailableError("Provider returned no refreshed access token")
    updated = service.update_tokens(
        current_user.id,
        workspace_id,
        account_id,
        access_token=access_token,
        refresh_token=str(payload["refresh_token"]) if payload.get("refresh_token") else None,
        expires_at=_expires_at(payload),
        granted_scopes=_scopes(payload, tuple(account.granted_scopes or [])),
    )
    return {
        "account_id": str(updated.id),
        "status": updated.status,
        "access_token_expires_at": updated.access_token_expires_at,
    }


@router.post("/{provider}/accounts/{account_id}/revoke", response_model=dict[str, object])
async def revoke(
    workspace_id: uuid.UUID,
    account_id: uuid.UUID,
    provider: Literal["facebook", "instagram", "threads", "linkedin", "youtube"],
    current_user: CurrentUser,
    session: SessionDep,
    settings: SettingsDep,
) -> dict[str, object]:
    config = provider_config(provider, settings)
    service = PublishingService(session, settings)
    account = service.account(current_user.id, workspace_id, account_id)
    if account.platform != provider:
        raise ConflictError("Provider does not match the connected account")
    access_token, _ = service.token_pair(account)
    if config.revoke_url:
        async with httpx.AsyncClient(timeout=20) as client:
            if provider in {"facebook", "instagram", "threads"}:
                response = await client.delete(
                    config.revoke_url,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
            else:
                revoke_data = {"token": access_token}
                if provider == "linkedin":
                    revoke_data.update(
                        {
                            "client_id": config.client_id or "",
                            "client_secret": config.client_secret or "",
                        }
                    )
                response = await client.post(
                    config.revoke_url,
                    data=revoke_data,
                    params={"client_id": config.client_id} if provider == "youtube" else None,
                )
            if response.status_code >= 400 and response.status_code not in {404, 405}:
                raise ProviderUnavailableError("Provider rejected token revocation")
    service.disconnect_account(current_user.id, workspace_id, account_id)
    return {"account_id": str(account_id), "status": "revoked"}


def profile_identity(provider: str, profile: dict[str, object]) -> tuple[str, str]:
    if provider == "instagram":
        external_id = str(profile.get("user_id") or profile.get("id") or "")
        display_name = str(profile.get("username") or "Instagram account")
        if not external_id:
            raise ProviderUnavailableError("Instagram did not return a business account id")
        return external_id, display_name
    if provider == "youtube":
        items = profile.get("items")
        if isinstance(items, list) and items and isinstance(items[0], dict):
            item = items[0]
            snippet_raw = item.get("snippet")
            snippet = cast(dict[str, object], snippet_raw) if isinstance(snippet_raw, dict) else {}
            return str(item.get("id", "youtube-channel")), str(
                snippet.get("title", "YouTube channel")
            )
    external_id = str(profile.get("id", ""))
    display_name = str(
        profile.get("name") or profile.get("username") or f"{provider.title()} account"
    )
    if not external_id:
        raise ProviderUnavailableError("Provider profile did not include an account id")
    return external_id, display_name
