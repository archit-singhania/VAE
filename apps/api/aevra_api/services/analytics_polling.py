"""Provider analytics polling for published posts.

The poller is intentionally conservative: it only reads metrics for jobs that
already have a provider post id, stores a timestamped snapshot, and never
logs access tokens or provider response bodies. Providers that do not expose
post-level metrics through the configured scopes are recorded as skipped so a
single unsupported platform cannot stop the worker batch.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import UUID

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from aevra_api.config import Settings
from aevra_api.db.models import PostMetric, PublishJob, SocialAccount
from aevra_api.services.publishing import PublishingService


class AnalyticsPoller:
    def __init__(self, session: Session, settings: Settings) -> None:
        self.session = session
        self.settings = settings
        self.publishing = PublishingService(session, settings)

    def collect(self, *, workspace_id: UUID | None = None, limit: int = 100) -> dict[str, int]:
        filters = [
            PublishJob.status.in_(("published", "verified")),
            PublishJob.external_post_id.is_not(None),
            SocialAccount.status == "connected",
        ]
        if workspace_id is not None:
            filters.append(PublishJob.workspace_id == workspace_id)
        rows = list(
            self.session.execute(
                select(PublishJob, SocialAccount)
                .join(SocialAccount, SocialAccount.id == PublishJob.social_account_id)
                .where(*filters)
                .order_by(PublishJob.updated_at.desc())
                .limit(limit)
            ).all()
        )
        collected = 0
        skipped = 0
        failed = 0
        with httpx.Client(timeout=30.0) as client:
            for job, account in rows:
                try:
                    values = self._fetch(account, str(job.external_post_id), client)
                    if values is None:
                        skipped += 1
                        continue
                    self.session.add(
                        PostMetric(
                            workspace_id=job.workspace_id,
                            social_account_id=account.id,
                            external_post_id=str(job.external_post_id),
                            collected_at=datetime.now(UTC),
                            impressions=values["impressions"],
                            engagements=values["engagements"],
                            clicks=values["clicks"],
                            likes=values["likes"],
                            comments=values["comments"],
                            shares=values["shares"],
                            metric_metadata={
                                "provider": account.platform,
                                "source": "provider_api",
                            },
                        )
                    )
                    collected += 1
                except (httpx.HTTPError, ValueError, KeyError):
                    failed += 1
            self.session.commit()
        return {"scanned": len(rows), "collected": collected, "skipped": skipped, "failed": failed}

    def _fetch(
        self, account: SocialAccount, external_post_id: str, client: httpx.Client
    ) -> dict[str, int] | None:
        access_token, _ = self.publishing.token_pair(account)
        if account.platform in {"facebook", "instagram", "threads"}:
            base = (
                "https://graph.threads.net/v1.0"
                if account.platform == "threads"
                else "https://graph.facebook.com/v23.0"
            )
            fields = (
                "id,views,likes,replies,reposts,quotes" if account.platform == "threads" else "id"
            )
            params: dict[str, str] = {"fields": fields}
            if account.platform == "instagram":
                params = {"metric": "impressions,likes,comments,shares,saved"}
                endpoint = f"{base}/{external_post_id}/insights"
            else:
                endpoint = f"{base}/{external_post_id}"
                if account.platform == "facebook":
                    params = {
                        "fields": (
                            "insights.metric(post_impressions,post_engaged_users),"
                            "likes.summary(true),comments.summary(true),shares"
                        )
                    }
            response = client.get(
                endpoint,
                params=params,
                headers={"Authorization": f"Bearer {access_token}"},
            )
            self._raise(response)
            if account.platform == "instagram":
                return _instagram_metrics(response.json())
            if account.platform == "threads":
                return _threads_metrics(response.json())
            return _graph_metrics(response.json())
        if account.platform == "youtube":
            response = client.get(
                "https://www.googleapis.com/youtube/v3/videos",
                params={"part": "statistics", "id": external_post_id},
                headers={"Authorization": f"Bearer {access_token}"},
            )
            self._raise(response)
            items = response.json().get("items", [])
            if not isinstance(items, list) or not items:
                return None
            statistics = items[0].get("statistics", {})
            return _youtube_metrics(statistics)
        # LinkedIn's basic member-posting scope does not expose reliable
        # post-level analytics. Keep the task healthy until analytics products
        # are approved for the connected organization/member.
        return None

    @staticmethod
    def _raise(response: httpx.Response) -> None:
        if response.status_code in {429} or response.status_code >= 500:
            raise httpx.HTTPStatusError(
                "provider temporarily unavailable", request=response.request, response=response
            )
        if response.status_code >= 400:
            raise ValueError("provider rejected analytics request")


def _graph_metrics(payload: dict[str, Any]) -> dict[str, int]:
    values = {
        "impressions": 0,
        "engagements": 0,
        "clicks": 0,
        "likes": 0,
        "comments": 0,
        "shares": 0,
    }
    insights = (
        payload.get("insights", {}).get("data", [])
        if isinstance(payload.get("insights"), dict)
        else []
    )
    for entry in insights if isinstance(insights, list) else []:
        if not isinstance(entry, dict):
            continue
        name = str(entry.get("name", ""))
        values_raw = entry.get("values", [])
        value = values_raw[0].get("value", 0) if isinstance(values_raw, list) and values_raw else 0
        try:
            number = int(value)
        except (TypeError, ValueError):
            number = 0
        if name in values:
            values[name] = max(0, number)
    for name in ("likes", "comments", "shares"):
        raw = payload.get(name)
        if isinstance(raw, dict):
            summary = raw.get("summary")
            if isinstance(summary, dict):
                values[name] = max(values[name], _safe_int(summary.get("total_count")))
        elif raw is not None:
            values[name] = max(values[name], _safe_int(raw))
    values["engagements"] = values["likes"] + values["comments"] + values["shares"]
    return values


def _instagram_metrics(payload: dict[str, Any]) -> dict[str, int]:
    values = {
        "impressions": 0,
        "engagements": 0,
        "clicks": 0,
        "likes": 0,
        "comments": 0,
        "shares": 0,
    }
    entries = payload.get("data", [])
    for entry in entries if isinstance(entries, list) else []:
        if not isinstance(entry, dict):
            continue
        name = str(entry.get("name", ""))
        if name not in values:
            continue
        raw_values = entry.get("values", [])
        value = raw_values[0].get("value", 0) if isinstance(raw_values, list) and raw_values else 0
        values[name] = _safe_int(value)
    values["engagements"] = values["likes"] + values["comments"] + values["shares"]
    return values


def _threads_metrics(payload: dict[str, Any]) -> dict[str, int]:
    likes = _safe_int(payload.get("likes"))
    comments = _safe_int(payload.get("replies"))
    shares = _safe_int(payload.get("reposts")) + _safe_int(payload.get("quotes"))
    return {
        "impressions": _safe_int(payload.get("views")),
        "engagements": likes + comments + shares,
        "clicks": 0,
        "likes": likes,
        "comments": comments,
        "shares": shares,
    }


def _safe_int(value: object) -> int:
    try:
        raw = value if isinstance(value, (str, int, float)) else 0
        return max(0, int(raw))
    except (TypeError, ValueError):
        return 0


def _youtube_metrics(payload: object) -> dict[str, int]:
    statistics = payload if isinstance(payload, dict) else {}

    def number(key: str) -> int:
        try:
            return max(0, int(statistics.get(key, 0)))
        except (TypeError, ValueError):
            return 0

    likes = number("likeCount")
    comments = number("commentCount")
    impressions = number("viewCount")
    return {
        "impressions": impressions,
        "engagements": likes + comments,
        "clicks": 0,
        "likes": likes,
        "comments": comments,
        "shares": 0,
    }
