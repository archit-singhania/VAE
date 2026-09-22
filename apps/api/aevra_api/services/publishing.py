from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from aevra_api.config import Settings
from aevra_api.db.models import PublishJob, SocialAccount
from aevra_api.domain.errors import ConflictError, ForbiddenError, NotFoundError
from aevra_api.publishing.contracts import (
    InstagramGraphPublisher,
    LinkedInPublisher,
    MetaFacebookPublisher,
    MockSocialPublisher,
    PublisherError,
    ThreadsGraphPublisher,
    YouTubeDataPublisher,
)
from aevra_api.publishing.contracts import PublishRequest as ProviderRequest
from aevra_api.repositories.publishing import PublishingRepository
from aevra_api.repositories.tenancy import TenancyRepository
from aevra_api.schemas.publishing import PublishRequest, SocialAccountCreateRequest
from aevra_api.token_vault import LocalTokenVault, TokenVaultError

EDIT_ROLES = {"owner", "admin", "member"}


class PublishingService:
    def __init__(self, session: Session, settings: Settings) -> None:
        self.session = session
        self.settings = settings
        self.repository = PublishingRepository(session)
        self.tenancy = TenancyRepository(session)
        self.mock = MockSocialPublisher()
        self.vault = LocalTokenVault(settings.token_vault_key or settings.secret_key)

    def _store_token(self, token: str) -> str:
        """Encrypt provider credentials before they touch the database."""
        return self.vault.encrypt(token)

    def _provider_token(self, stored_value: str) -> str:
        """Read encrypted credentials, accepting legacy staging references once."""
        try:
            return self.vault.decrypt(stored_value)
        except TokenVaultError:
            # Existing staging records predate the vault. They are replaced by
            # an encrypted envelope on the next account connection.
            return stored_value

    def _access(self, user_id: uuid.UUID, workspace_id: uuid.UUID) -> str:
        access = self.tenancy.get_workspace_access(user_id, workspace_id)
        if access is None:
            raise NotFoundError("Workspace not found")
        return access[1]

    def _editor(self, user_id: uuid.UUID, workspace_id: uuid.UUID) -> None:
        if self._access(user_id, workspace_id) not in EDIT_ROLES:
            raise ForbiddenError("Publishing editor access is required")

    def list_accounts(self, user_id: uuid.UUID, workspace_id: uuid.UUID) -> list[SocialAccount]:
        self._access(user_id, workspace_id)
        return self.repository.accounts(user_id, workspace_id)

    def connect_account(
        self, user_id: uuid.UUID, workspace_id: uuid.UUID, request: SocialAccountCreateRequest
    ) -> SocialAccount:
        return self.connect_credentials(
            user_id,
            workspace_id,
            request,
            refresh_token=None,
            expires_at=None,
            granted_scopes=request.capabilities,
        )

    def connect_credentials(
        self,
        user_id: uuid.UUID,
        workspace_id: uuid.UUID,
        request: SocialAccountCreateRequest,
        *,
        refresh_token: str | None,
        expires_at: datetime | None,
        granted_scopes: list[str],
        account_metadata: dict[str, object] | None = None,
    ) -> SocialAccount:
        """Create/update an account while keeping all provider tokens encrypted."""
        self._editor(user_id, workspace_id)
        existing = self.repository.account_by_identity(
            workspace_id, request.platform, request.external_account_id
        )
        if existing is not None:
            existing.display_name = request.display_name.strip()
            existing.access_token_ref = self._store_token(request.access_token_ref)
            existing.refresh_token_ref = (
                self._store_token(refresh_token) if refresh_token else existing.refresh_token_ref
            )
            existing.access_token_expires_at = expires_at
            existing.granted_scopes = granted_scopes
            existing.capabilities = request.capabilities
            if account_metadata:
                existing.account_metadata = {**existing.account_metadata, **account_metadata}
            existing.status = "connected"
            existing.last_verified_at = datetime.now(UTC)
            self.session.commit()
            return existing
        account = SocialAccount(
            workspace_id=workspace_id,
            created_by_user_id=user_id,
            platform=request.platform,
            external_account_id=request.external_account_id.strip(),
            display_name=request.display_name.strip(),
            access_token_ref=self._store_token(request.access_token_ref),
            refresh_token_ref=self._store_token(refresh_token) if refresh_token else None,
            access_token_expires_at=expires_at,
            granted_scopes=granted_scopes,
            capabilities=request.capabilities,
            account_metadata=account_metadata or {},
            status="connected",
            last_verified_at=datetime.now(UTC),
        )
        self.session.add(account)
        self.session.commit()
        return account

    def account(
        self, user_id: uuid.UUID, workspace_id: uuid.UUID, account_id: uuid.UUID
    ) -> SocialAccount:
        account = self.repository.account(user_id, workspace_id, account_id)
        if account is None:
            raise NotFoundError("Connected social account not found")
        return account

    def update_tokens(
        self,
        user_id: uuid.UUID,
        workspace_id: uuid.UUID,
        account_id: uuid.UUID,
        *,
        access_token: str,
        refresh_token: str | None = None,
        expires_at: datetime | None = None,
        granted_scopes: list[str] | None = None,
    ) -> SocialAccount:
        self._editor(user_id, workspace_id)
        account = self.account(user_id, workspace_id, account_id)
        account.access_token_ref = self._store_token(access_token)
        if refresh_token:
            account.refresh_token_ref = self._store_token(refresh_token)
        account.access_token_expires_at = expires_at
        if granted_scopes is not None:
            account.granted_scopes = granted_scopes
        account.status = "connected"
        account.last_verified_at = datetime.now(UTC)
        self.session.commit()
        return account

    def token_pair(self, account: SocialAccount) -> tuple[str, str | None]:
        access = self._provider_token(account.access_token_ref)
        refresh = (
            self._provider_token(account.refresh_token_ref) if account.refresh_token_ref else None
        )
        return access, refresh

    def revoke_account(
        self, user_id: uuid.UUID, workspace_id: uuid.UUID, account_id: uuid.UUID
    ) -> SocialAccount:
        self._editor(user_id, workspace_id)
        account = self.account(user_id, workspace_id, account_id)
        account.status = "revoked"
        account.last_verified_at = datetime.now(UTC)
        self.session.commit()
        return account

    def disconnect_account(
        self, user_id: uuid.UUID, workspace_id: uuid.UUID, account_id: uuid.UUID
    ) -> None:
        self._editor(user_id, workspace_id)
        account = self.account(user_id, workspace_id, account_id)
        account.status = "revoked"
        account.access_token_ref = self._store_token("revoked")
        account.refresh_token_ref = None
        self.session.commit()

    def _publisher(self, platform: str):
        if platform == "linkedin":
            return LinkedInPublisher()
        publishers = {
            "instagram": InstagramGraphPublisher,
            "facebook": MetaFacebookPublisher,
            "threads": ThreadsGraphPublisher,
            "youtube": YouTubeDataPublisher,
        }
        publisher_type = publishers.get(platform)
        if publisher_type is None:
            return self.mock
        return publisher_type()

    def publish(
        self, user_id: uuid.UUID, workspace_id: uuid.UUID, request: PublishRequest
    ) -> PublishJob:
        self._editor(user_id, workspace_id)
        account = self.repository.account(user_id, workspace_id, request.social_account_id)
        if account is None or account.status != "connected":
            raise NotFoundError("Connected social account not found")
        existing = self.repository.job_by_key(workspace_id, request.idempotency_key)
        if existing is not None:
            return existing
        job = PublishJob(
            workspace_id=workspace_id,
            campaign_id=request.campaign_id,
            social_account_id=account.id,
            created_by_user_id=user_id,
            idempotency_key=request.idempotency_key,
            status="publishing",
            payload={"text": request.text, "media_urls": request.media_urls},
            attempts=1,
        )
        self.session.add(job)
        self.session.flush()
        try:
            publisher = self._publisher(account.platform)
            result = publisher.publish(
                ProviderRequest(
                    request.idempotency_key,
                    account.external_account_id,
                    request.text,
                    tuple(request.media_urls),
                ),
                access_token=self._provider_token(account.access_token_ref),
            )
            job.status = "published"
            job.external_post_id = result.external_post_id
            job.external_url = result.external_url
            job.published_at = result.published_at
            job.payload = {
                **job.payload,
                "provider": result.provider,
                "provider_metadata": result.raw_metadata,
            }
        except PublisherError as error:
            job.status = "failed"
            job.retryable = error.retryable
            job.error_message = str(error)
        self.session.commit()
        return job

    def verify(self, user_id: uuid.UUID, workspace_id: uuid.UUID, job_id: uuid.UUID) -> PublishJob:
        self._editor(user_id, workspace_id)
        job = self.repository.job(user_id, workspace_id, job_id)
        if job is None:
            raise NotFoundError("Publish job not found")
        if not job.external_post_id:
            raise ConflictError("Publish job has no external post to verify")
        account = self.repository.account(user_id, workspace_id, job.social_account_id)
        if account is None:
            raise NotFoundError("Connected social account not found")
        try:
            result = self._publisher(account.platform).verify(
                job.external_post_id, access_token=self._provider_token(account.access_token_ref)
            )
            job.status = "verified"
            job.verified_at = datetime.now(UTC)
            job.payload = {**job.payload, "verification": result.raw_metadata}
        except PublisherError as error:
            job.status = "failed"
            job.retryable = error.retryable
            job.error_message = str(error)
        self.session.commit()
        return job
