import json
import uuid
from datetime import UTC, datetime, timedelta

from conftest import bearer, register_account
from sqlalchemy import select

from aevra_api.db.models import (
    CampaignRun,
    MediaAsset,
    OrganizationMember,
    PostMetric,
    PublishJob,
    ScheduledPost,
    SocialAccount,
    User,
)


def account(client, name):
    return register_account(
        client, email=f"{name}@example.test", organization_name=name, workspace_name=name
    )


def test_admin_login_and_reporting_are_role_protected(client, session):
    customer = account(client, "customer")
    client.cookies.clear()
    assert client.get("/api/v1/auth/admin/overview").status_code == 401
    assert client.get("/api/v1/auth/admin/overview", headers=bearer(customer)).status_code == 403
    denied = client.post(
        "/api/v1/auth/admin/login",
        json={
            "email": "customer@example.test",
            "password": "AevraTestPassword!2026",
        },
    )
    assert denied.status_code == 403
    assert "set-cookie" not in denied.headers
    user = session.scalar(select(User).where(User.email == "customer@example.test"))
    user.is_admin = True
    session.commit()
    approved = client.post(
        "/api/v1/auth/admin/login",
        json={
            "email": user.email,
            "password": "AevraTestPassword!2026",
        },
    )
    assert approved.status_code == 200
    assert "httponly" in approved.headers["set-cookie"].lower()
    report = client.get("/api/v1/auth/admin/overview")
    assert report.status_code == 200
    assert report.json()["users_total"] == 0


def test_usage_counts_latest_metrics_and_excludes_private_content(client, session):
    customer = account(client, "creator")
    second = account(client, "colleague")
    admin = account(client, "operator")
    admin_user = session.get(User, uuid.UUID(admin["user"]["id"]))
    admin_user.is_admin = True
    wid = uuid.UUID(customer["workspace"]["id"])
    uid = uuid.UUID(customer["user"]["id"])
    # Shared membership must not duplicate platform/headline totals.
    session.add(
        OrganizationMember(
            user_id=uuid.UUID(second["user"]["id"]),
            organization_id=uuid.UUID(customer["organization"]["id"]),
            role="member",
        )
    )
    channel = SocialAccount(
        workspace_id=wid,
        created_by_user_id=uid,
        platform="instagram",
        display_name="PRIVATE HANDLE",
        external_account_id="private-id",
        access_token_ref="PRIVATE TOKEN",
        status="connected",
    )
    session.add(channel)
    session.flush()
    now = datetime.now(UTC)
    for state in ("queued", "published", "failed", "cancelled", "verified"):
        session.add(
            PublishJob(
                workspace_id=wid,
                created_by_user_id=uid,
                social_account_id=channel.id,
                status=state,
                idempotency_key=state,
                payload={"text": "PRIVATE CAPTION"},
            )
        )
    for state in ("scheduled", "published", "failed", "cancelled"):
        session.add(
            ScheduledPost(
                workspace_id=wid,
                created_by_user_id=uid,
                social_account_id=channel.id,
                status=state,
                scheduled_for=now,
                idempotency_key=state,
                payload={"text": "PRIVATE SCHEDULE"},
            )
        )
    for offset, impressions in ((-1, 100), (0, 150)):
        session.add(
            PostMetric(
                workspace_id=wid,
                social_account_id=channel.id,
                external_post_id="private-post",
                collected_at=now + timedelta(days=offset),
                impressions=impressions,
                engagements=impressions // 10,
                clicks=2,
            )
        )
    session.add(
        MediaAsset(
            workspace_id=wid,
            created_by_user_id=uid,
            media_type="image",
            asset_role="generated",
            status="ready",
            storage_key="private-file",
            filename="PRIVATE FILE",
            mime_type="image/png",
            sha256="0" * 64,
            generation_provider="test-image",
            prompt="PRIVATE PROMPT",
        )
    )
    session.commit()
    response = client.get("/api/v1/auth/admin/overview", headers=bearer(admin))
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["totals"]["published"] == 2
    assert data["totals"]["scheduled"] == 1
    assert data["totals"]["failed"] == 1
    assert data["totals"]["schedule_failed"] == 1
    assert data["totals"]["impressions"] == 150
    assert data["totals"]["engagements"] == 15
    assert data["totals"]["channels"] == 1
    assert data["platforms"][0]["platform"] == "instagram"
    assert data["models"][0]["requests"] == 1
    assert len(data["users"]) == 2
    assert all(row["platforms"][0]["impressions"] == 150 for row in data["users"])
    for forbidden in ("PRIVATE", "access_token", "email", "password", "private-post", "payload"):
        assert forbidden not in json.dumps(data)


def test_llm_usage_reports_recorded_tokens_without_model_outputs(client, session):
    from test_phase_5_6_campaigns import create_brand, create_campaign

    customer = account(client, "writer")
    brand = create_brand(client, customer)
    campaign = create_campaign(client, customer, brand["id"], ["instagram", "facebook"])
    admin = account(client, "admin")
    session.get(User, uuid.UUID(admin["user"]["id"])).is_admin = True
    for index, metadata in enumerate(
        (
            {
                "provider": "test-llm",
                "model": "test-model",
                "prompt_tokens": 120,
                "completion_tokens": 80,
                "output": "PRIVATE OUTPUT",
            },
            {},
        ),
        1,
    ):
        session.add(
            CampaignRun(
                workspace_id=uuid.UUID(customer["workspace"]["id"]),
                campaign_id=uuid.UUID(campaign["id"]),
                run_number=index,
                revision=index,
                status="completed",
                started_at=datetime.now(UTC),
                provider_metadata=metadata,
                state_snapshot={"prompt": "PRIVATE INPUT"},
            )
        )
    session.commit()
    response = client.get("/api/v1/auth/admin/overview", headers=bearer(admin))
    assert response.status_code == 200
    data = response.json()
    assert data["totals"]["generation_runs"] == 2
    assert data["totals"]["prompt_tokens"] == 120
    assert data["totals"]["completion_tokens"] == 80
    measured = next(row for row in data["models"] if row["model"] == "test-model")
    assert measured["metered_runs"] == 1
    assert "PRIVATE" not in response.text
