"""Allowlisted operational reporting. Never serialize customer content or credentials."""

from collections import defaultdict
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from aevra_api.db.models import (
    CampaignRun,
    MediaAsset,
    OrganizationMember,
    PostMetric,
    PublishJob,
    ScheduledPost,
    SocialAccount,
    User,
    Workspace,
)


def build_admin_overview(session: Session) -> dict[str, object]:
    users = session.scalars(select(User).where(User.is_admin.is_(False))).all()
    memberships = session.execute(
        select(OrganizationMember.user_id, Workspace.id)
        .join(Workspace, Workspace.organization_id == OrganizationMember.organization_id)
        .where(OrganizationMember.user_id.in_([user.id for user in users]))
    ).all()
    user_spaces = defaultdict(set)
    for user_id, workspace_id in memberships:
        user_spaces[user_id].add(workspace_id)
    spaces = {workspace_id for _, workspace_id in memberships}
    usage = defaultdict(lambda: defaultdict(int))
    platforms = defaultdict(lambda: defaultdict(int))
    models = defaultdict(lambda: defaultdict(int))
    workspace_platforms = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))

    def add_platform(workspace_id, platform, key, value):
        platforms[platform][key] += value
        workspace_platforms[workspace_id][platform][key] += value

    def grouped(model, *columns):
        return session.execute(
            select(model.workspace_id, *columns, func.count())
            .where(model.workspace_id.in_(spaces))
            .group_by(model.workspace_id, *columns)
        ).all()

    for workspace_id, role, provider, media_type, status, count in grouped(
        MediaAsset,
        MediaAsset.asset_role,
        MediaAsset.generation_provider,
        MediaAsset.media_type,
        MediaAsset.status,
    ):
        usage[workspace_id]["assets"] += count
        if role == "generated":
            usage[workspace_id]["generated_assets"] += count
            bucket = models[("media", provider or "Unreported", media_type)]
            bucket["requests"] += count
            bucket["failed"] += count if status == "failed" else 0

    for workspace_id, platform, status, count in grouped(
        SocialAccount,
        SocialAccount.platform,
        SocialAccount.status,
    ):
        usage[workspace_id]["channels"] += count
        add_platform(workspace_id, platform, "channels", count)
        if status == "connected":
            add_platform(workspace_id, platform, "connected", count)

    for model, pending in (
        (PublishJob, ("queued", "publishing")),
        (ScheduledPost, ("scheduled", "processing")),
    ):
        rows = session.execute(
            select(model.workspace_id, SocialAccount.platform, model.status, func.count())
            .join(SocialAccount, SocialAccount.id == model.social_account_id)
            .where(model.workspace_id.in_(spaces))
            .group_by(model.workspace_id, SocialAccount.platform, model.status)
        ).all()
        for workspace_id, platform, status, count in rows:
            # A fulfilled schedule already has a publish job: count success only once.
            key = "scheduled" if model is ScheduledPost else "queued"
            if status in pending:
                usage[workspace_id][key] += count
                add_platform(workspace_id, platform, key, count)
            if model is PublishJob and status in ("published", "verified"):
                usage[workspace_id]["published"] += count
                add_platform(workspace_id, platform, "published", count)
            if status == "failed":
                failure_key = "schedule_failed" if model is ScheduledPost else "failed"
                usage[workspace_id][failure_key] += count
                add_platform(workspace_id, platform, failure_key, count)

    # Metrics are cumulative snapshots. Only the latest sample per account/post counts.
    ranked = (
        select(
            PostMetric.id,
            func.row_number()
            .over(
                partition_by=(
                    PostMetric.workspace_id,
                    PostMetric.social_account_id,
                    PostMetric.external_post_id,
                ),
                order_by=(PostMetric.collected_at.desc(), PostMetric.id.desc()),
            )
            .label("position"),
        )
        .where(PostMetric.workspace_id.in_(spaces))
        .subquery()
    )
    metric_rows = session.execute(
        select(
            PostMetric.workspace_id,
            SocialAccount.platform,
            PostMetric.impressions,
            PostMetric.engagements,
            PostMetric.clicks,
            PostMetric.collected_at,
        )
        .join(ranked, ranked.c.id == PostMetric.id)
        .join(SocialAccount, SocialAccount.id == PostMetric.social_account_id)
        .where(ranked.c.position == 1)
    ).all()
    for workspace_id, platform, impressions, engagements, clicks, _ in metric_rows:
        for key, value in (
            ("impressions", impressions),
            ("engagements", engagements),
            ("clicks", clicks),
            ("measured_posts", 1),
        ):
            usage[workspace_id][key] += value
            add_platform(workspace_id, platform, key, value)

    # Read metadata only; exclude prompts, model outputs and workflow snapshots.
    runs = session.execute(
        select(CampaignRun.workspace_id, CampaignRun.status, CampaignRun.provider_metadata).where(
            CampaignRun.workspace_id.in_(spaces)
        )
    ).all()
    for workspace_id, status, metadata in runs:
        usage[workspace_id]["generation_runs"] += 1
        metadata = metadata or {}
        bucket = models[
            (
                "llm",
                str(metadata.get("provider") or "Unreported"),
                str(metadata.get("model") or "Unreported"),
            )
        ]
        bucket["requests"] += 1
        bucket["failed"] += int(status == "failed")
        for key in ("prompt_tokens", "completion_tokens"):
            value = metadata.get(key)
            if isinstance(value, int) and not isinstance(value, bool) and value >= 0:
                bucket[key] += value
                usage[workspace_id][key] += value
        bucket["metered_runs"] += int(
            isinstance(metadata.get("prompt_tokens"), int)
            and isinstance(metadata.get("completion_tokens"), int)
        )

    keys = (
        "assets",
        "generated_assets",
        "channels",
        "scheduled",
        "queued",
        "published",
        "failed",
        "schedule_failed",
        "impressions",
        "engagements",
        "clicks",
        "measured_posts",
        "generation_runs",
        "prompt_tokens",
        "completion_tokens",
    )

    def summarize(workspace_ids):
        return {key: sum(usage[wid][key] for wid in workspace_ids) for key in keys}

    def customer_platforms(workspace_ids):
        names = {name for wid in workspace_ids for name in workspace_platforms[wid]}
        return [
            {
                "platform": name,
                **{
                    key: sum(workspace_platforms[wid][name][key] for wid in workspace_ids)
                    for key in ("channels", "scheduled", "published", "impressions", "engagements")
                },
            }
            for name in sorted(names)
        ]

    totals = summarize(spaces)
    return {
        "users_total": len(users),
        "users_approved": sum(user.account_status == "approved" for user in users),
        "assets_total": totals["assets"],
        "channels_total": totals["channels"],
        "totals": totals,
        "users": [
            {
                "user_id": str(user.id),
                "display_name": user.display_name,
                "brand_name": user.brand_name,
                "account_type": user.account_type,
                "account_status": user.account_status,
                "created_at": user.created_at.isoformat(),
                **summarize(user_spaces[user.id]),
                "platforms": customer_platforms(user_spaces[user.id]),
            }
            for user in users
        ],
        "platforms": [
            {"platform": platform, **{key: values[key] for key in (*keys, "connected")}}
            for platform, values in sorted(platforms.items())
        ],
        "models": [
            {
                "kind": kind,
                "provider": provider,
                "model": model,
                **{
                    key: values[key]
                    for key in (
                        "requests",
                        "failed",
                        "prompt_tokens",
                        "completion_tokens",
                        "metered_runs",
                    )
                },
            }
            for (kind, provider, model), values in sorted(models.items())
        ],
        "metrics_updated_at": max((row[-1] for row in metric_rows), default=None),
        "generated_at": datetime.now(UTC).isoformat(),
    }
