import json
import uuid
from datetime import UTC, datetime, timedelta

from conftest import bearer, register_account
from test_ml_insights import history, predictive_history

from aevra_api.db.models import PostMetric, PublishJob, SocialAccount
from aevra_api.services.advanced_analytics import (
    advanced_analyze,
    compare_drafts,
    content_map,
    data_quality,
)
from aevra_api.services.ml_insights import History, load_history


def test_map_is_deterministic_finite_and_distinguishes_zero_from_missing():
    data = history()
    data.posts = [{"id": "0", "rate": 0}]
    first = content_map(data)
    assert first == content_map(data)
    assert first["status"] == "ready"
    assert len(first["points"]) == 10
    assert first["points"][0]["engagement_rate"] == 0
    assert first["points"][1]["engagement_rate"] is None
    assert 0 <= first["explained_variance"] <= 1
    assert all(0 <= p["x"] <= 1 and 0 <= p["y"] <= 1 for p in first["points"])
    json.dumps(first, allow_nan=False)


def test_map_abstains_on_insufficient_and_identical_vectors():
    assert content_map(History([], [], [], [], {}))["status"] == "needs_data"
    data = history()
    for row in data.texts:
        row["text"] = "the same repeated sentence"
    assert content_map(data)["status"] == "needs_data"


def test_same_draft_has_zero_comparison_and_finite_bootstrap_range():
    data = predictive_history()
    now = datetime.now(UTC)
    report = compare_drafts(data, "coffee " * 30, "coffee " * 30, "instagram", now)
    assert report["status"] == "ready", report
    assert report["delta"] == 0
    assert report["delta_range"] == [0, 0]
    assert report["bootstrap_samples"] == 60
    assert report["diagnostics"]["holdout_mae"] < report["diagnostics"]["baseline_mae"]
    json.dumps(report, allow_nan=False)


def test_comparison_returns_signed_difference_and_preserves_validation_gates():
    data = predictive_history()
    now = datetime.now(UTC)
    result = compare_drafts(data, "coffee " * 15, "coffee " * 45, "instagram", now)
    assert result["status"] == "ready", result
    assert result["delta"] > 0
    assert result["delta_range"][0] > 0
    assert compare_drafts(data, "", "caption", "instagram", now)["status"] == "needs_data"
    assert (
        compare_drafts(data, "coffee " * 30, "x " * 500, "instagram", now)["status"] == "unreliable"
    )
    assert (
        compare_drafts(predictive_history(True), "coffee " * 30, "coffee " * 45, "instagram", now)[
            "status"
        ]
        == "unreliable"
    )


def shifted_history(now, shifted=True):
    data = History([], [], [], [], {})
    for i in range(28):
        data.posts.append(
            {
                "id": str(i),
                "published": now - timedelta(days=35.5 - i),
                "platform": "instagram",
                "rate": 20 if shifted and i >= 14 else 2,
            }
        )
    return data


def test_distribution_permutation_check_handles_ties_and_is_platform_scoped():
    now = datetime.now(UTC)
    data = shifted_history(now)
    result = data_quality(data, "instagram", now)["drift"]
    assert result["status"] == "difference_detected"
    assert result["ks_distance"] == 1
    assert result["permutation_p"] == 0.005
    assert result["previous_samples"] == result["recent_samples"] == 14
    unchanged = data_quality(shifted_history(now, False), "instagram", now)["drift"]
    assert unchanged["status"] == "no_clear_difference"
    assert unchanged["permutation_p"] == 1
    assert data_quality(data, "youtube", now)["drift"]["status"] == "needs_data"


def test_quality_reports_missing_data_and_freshness_without_inventing_zero_coverage():
    now = datetime.now(UTC)
    data = History([], [], [], [], {now.date(): {"post": 1}})
    report = data_quality(data, "instagram", now)
    assert report["coverage_percent"] is None
    assert report["observed_days"] == 1 and report["missing_days"] == 34
    data.quality = {
        "mature_published_posts": 80,
        "mature_matched_posts": 20,
        "latest_metric_at": (now - timedelta(hours=5)).isoformat(),
    }
    report = data_quality(data, "instagram", now)
    assert report["coverage_percent"] == 25
    assert report["freshness_hours"] == 5


def register(client, name):
    return register_account(
        client, email=f"{name}@example.test", organization_name=name, workspace_name=name
    )


def test_advanced_endpoint_auth_scope_input_limits_and_read_only_behavior(client):
    one, two = register(client, "advanced-one"), register(client, "advanced-two")
    path = f"/api/v1/workspaces/{one['workspace']['id']}/ml/advanced"
    assert client.post(path, headers=bearer(two), json={}).status_code == 404
    client.cookies.clear()
    assert client.post(path, json={}).status_code == 401
    assert (
        client.post(path, headers=bearer(one), json={"alternative_draft": "x" * 6001}).status_code
        == 422
    )
    response = client.post(path, headers=bearer(one), json={"draft": "UNSAVED_PRIVATE_DRAFT"})
    assert response.status_code == 200, response.text
    assert response.json()["audit"]["drafts_saved"] is False
    assert response.json()["data_quality"]["mature_posts"] == 0
    assert "UNSAVED_PRIVATE_DRAFT" not in response.text


def test_coverage_denominator_excludes_immature_posts(client, session):
    user = register(client, "coverage")
    uid, wid = uuid.UUID(user["user"]["id"]), uuid.UUID(user["workspace"]["id"])
    channel = SocialAccount(
        workspace_id=wid,
        created_by_user_id=uid,
        platform="instagram",
        display_name="Account",
        external_account_id="private",
        access_token_ref="secret",
    )
    session.add(channel)
    session.flush()
    now = datetime.now(UTC)
    for key, age in (("matched", 10), ("unmatched", 12), ("immature", 2)):
        session.add(
            PublishJob(
                workspace_id=wid,
                created_by_user_id=uid,
                social_account_id=channel.id,
                idempotency_key=key,
                external_post_id=key,
                published_at=now - timedelta(days=age),
                status="published",
                payload={"text": key},
            )
        )
    session.add(
        PostMetric(
            workspace_id=wid,
            social_account_id=channel.id,
            external_post_id="matched",
            collected_at=now - timedelta(days=3),
            impressions=100,
            engagements=5,
        )
    )
    session.commit()
    data = load_history(session, uid, wid)
    quality = data_quality(data, "instagram", now)
    assert quality["mature_posts"] == 2
    assert quality["matched_posts"] == 1
    assert quality["coverage_percent"] == 50


def test_advanced_empty_report_is_serializable_and_contains_three_sections():
    response = advanced_analyze(History([], [], [], [], {}), "", "", "instagram")
    assert {"content_map", "comparison", "data_quality"} <= set(response)
    assert response["audit"]["external_requests"] == 0
    json.dumps(response, allow_nan=False)
