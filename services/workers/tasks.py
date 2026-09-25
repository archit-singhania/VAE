"""Retry-safe worker task declarations.

The task bodies intentionally delegate to application services. No provider
credentials or prompt state is kept in Celery payloads.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

from aevra_api.config import get_settings
from aevra_api.db.models import (
    AccountDeletionRequest,
    OAuthState,
    OrganizationMember,
    ScheduledPost,
    SocialAccount,
    User,
    Workspace,
)
from aevra_api.db.session import SessionLocal
from aevra_api.domain.errors import DomainError
from aevra_api.publishing.contracts import PublisherError
from aevra_api.schemas.publishing import PublishRequest
from aevra_api.services.analytics_polling import AnalyticsPoller
from aevra_api.services.publishing import PublishingService
from sqlalchemy import delete, select, update

from services.workers.celery_app import celery_app


def _task(**kwargs: Any):
    def decorator(function: Any) -> Any:
        return (
            celery_app.task(**kwargs)(function) if celery_app is not None else function
        )

    return decorator


@_task(
    bind=True,
    autoretry_for=(TimeoutError, ConnectionError),
    retry_backoff=True,
    retry_backoff_max=600,
    retry_jitter=True,
    max_retries=5,
)
def dispatch_due_posts(_task_instance: Any) -> dict[str, str | int]:
    """Claim and publish due scheduled posts idempotently."""
    session = SessionLocal()
    processed = 0
    try:
        due = list(
            session.query(ScheduledPost)
            .filter(
                ScheduledPost.status == "scheduled",
                ScheduledPost.scheduled_for <= datetime.now(UTC),
            )
            .order_by(ScheduledPost.scheduled_for)
            .limit(25)
            .all()
        )
        for item in due:
            # Compare-and-set claim prevents overlapping workers dispatching one schedule.
            claimed = session.execute(
                update(ScheduledPost)
                .where(ScheduledPost.id == item.id, ScheduledPost.status == "scheduled")
                .values(status="processing", attempts=ScheduledPost.attempts + 1)
                .execution_options(synchronize_session=False)
            )
            session.commit()
            if claimed.rowcount != 1:
                continue
            session.refresh(item)
            payload = item.payload if isinstance(item.payload, dict) else {}
            media_payload = payload.get("media_urls", [])
            media_urls = (
                [str(url) for url in media_payload]
                if isinstance(media_payload, list)
                else []
            )
            try:
                job = PublishingService(session, get_settings()).publish(
                    item.created_by_user_id,
                    item.workspace_id,
                    PublishRequest(
                        campaign_id=item.campaign_id,
                        social_account_id=item.social_account_id,
                        idempotency_key=f"scheduled:{item.idempotency_key}",
                        text=str(payload.get("text", "")),
                        media_urls=media_urls,
                    ),
                )
                item.published_job_id = job.id
                item.status = (
                    "published" if job.status in {"published", "verified"} else "failed"
                )
                item.error_message = job.error_message
            except PublisherError as error:
                item.error_message = str(error)[:1000]
                if error.retryable and item.attempts < 5:
                    item.status = "scheduled"
                    item.scheduled_for = datetime.now(UTC) + timedelta(
                        seconds=min(3600, 30 * (2 ** (item.attempts - 1)))
                    )
                else:
                    item.status = "failed"
            except (DomainError, TimeoutError, ConnectionError, ValueError) as error:
                item.status = "failed"
                item.error_message = str(error)[:1000]
            session.commit()
            processed += 1
        return {
            "status": "completed",
            "job": "dispatch_due_posts",
            "processed": processed,
        }
    finally:
        session.close()


@_task(
    bind=True,
    autoretry_for=(TimeoutError, ConnectionError),
    retry_backoff=True,
    retry_backoff_max=1800,
    retry_jitter=True,
    max_retries=5,
)
def collect_post_metrics(_task_instance: Any) -> dict[str, str | int]:
    """Poll provider APIs and persist a normalized metric snapshot batch."""
    session = SessionLocal()
    try:
        result = AnalyticsPoller(session, get_settings()).collect()
        return {"status": "completed", "job": "collect_post_metrics", **result}
    finally:
        session.close()


@_task(
    bind=True,
    autoretry_for=(TimeoutError, ConnectionError),
    retry_backoff=True,
    retry_backoff_max=3600,
    retry_jitter=True,
    max_retries=5,
)
def execute_account_deletions(_task_instance: Any) -> dict[str, str | int]:
    """Execute due deletion requests without leaving encrypted provider tokens behind."""
    session = SessionLocal()
    processed = 0
    try:
        requests = list(
            session.scalars(
                select(AccountDeletionRequest)
                .where(
                    AccountDeletionRequest.status == "requested",
                    AccountDeletionRequest.scheduled_for <= datetime.now(UTC),
                )
                .order_by(AccountDeletionRequest.scheduled_for)
                .limit(25)
                .with_for_update(skip_locked=True)
            ).all()
        )
        for request in requests:
            request.status = "processing"
            workspace_ids = list(
                session.scalars(
                    select(Workspace.id)
                    .join(
                        OrganizationMember,
                        OrganizationMember.organization_id == Workspace.organization_id,
                    )
                    .where(OrganizationMember.user_id == request.user_id)
                ).all()
            )
            if workspace_ids:
                session.execute(
                    delete(SocialAccount).where(
                        SocialAccount.workspace_id.in_(workspace_ids)
                    )
                )
            user = session.get(User, request.user_id)
            if user is not None:
                user.email = f"deleted+{user.id}@invalid.local"
                user.display_name = "Deleted user"
                user.password_hash = "deleted"
                user.is_active = False
            request.status = "completed"
            request.completed_at = datetime.now(UTC)
            session.commit()
            processed += 1
        return {
            "status": "completed",
            "job": "execute_account_deletions",
            "processed": processed,
        }
    finally:
        session.close()


@_task(bind=True)
def prune_oauth_states(_task_instance: Any) -> dict[str, str | int]:
    """Remove expired/consumed OAuth nonces so the state table stays bounded."""
    session = SessionLocal()
    try:
        cutoff = datetime.now(UTC) - timedelta(days=1)
        result = session.execute(
            delete(OAuthState).where(
                (OAuthState.expires_at < datetime.now(UTC))
                | (
                    OAuthState.consumed_at.is_not(None)
                    & (OAuthState.consumed_at < cutoff)
                )
            )
        )
        session.commit()
        return {
            "status": "completed",
            "job": "prune_oauth_states",
            "deleted": int(getattr(result, "rowcount", 0) or 0),
        }
    finally:
        session.close()
