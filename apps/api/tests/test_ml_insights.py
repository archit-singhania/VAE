import json
import uuid
from datetime import UTC, datetime, timedelta

import numpy as np
from conftest import bearer, register_account

from aevra_api.db.models import MediaAsset, PostMetric, PublishJob, SocialAccount
from aevra_api.services.ml_insights import (
    History,
    analyze,
    anomaly_feature,
    forecast_feature,
    load_history,
    prediction_features,
)


def history():
    captions = [
        "Fresh coffee roasted every morning with a rich aroma #coffee #roastery",
        "Coffee beans sourced sustainably for your morning espresso #coffee #sustainable",
        "Discover espresso roasting and learn to brew delicious coffee #espresso #coffee",
        "Our new coffee blend tastes rich and smooth #coffee #blend",
        "Coffee lovers enjoy a fragrant espresso at our local cafe #coffee #cafe",
        "Summer hiking gear for mountain adventures #hiking #outdoors",
        "Explore wild mountain trails with durable hiking boots #hiking #trails",
        "Plan your next trek through beautiful mountain scenery #hiking #adventure",
        "Outdoor hiking jackets keep you warm in the mountains #outdoors #hiking",
        "Comfortable boots for mountain climbing and hiking #hiking #boots",
    ]
    return History(
        texts=[
            {"id": str(i), "text": text, "platform": "instagram"} for i, text in enumerate(captions)
        ],
        approved=captions[:5],
        assets=[
            {
                "id": "coffee-image",
                "text": "Fresh coffee beans espresso roasting",
                "label": "coffee.jpg",
            },
            {"id": "hiking-image", "text": "Snowy mountains hiking boots", "label": "hiking.jpg"},
        ],
        posts=[],
        daily={},
    )


def test_all_ten_features_have_honest_empty_states():
    report = analyze(History([], [], [], [], {}), "", "instagram")
    assert len(report["features"]) == 10
    assert len({f["id"] for f in report["features"]}) == 10
    assert all(f["status"] == "needs_data" and not f["items"] for f in report["features"])
    assert report["audit"]["external_requests"] == 0
    assert report["audit"]["automatic_actions"] is False


def test_five_text_models_learn_workspace_corpus_and_are_deterministic():
    data = history()
    draft = data.texts[0]["text"]
    first = analyze(data, draft, "instagram")
    second = analyze(data, draft, "instagram")
    features = {f["id"]: f for f in first["features"]}
    assert all(
        features[key]["status"] == "ready"
        for key in ("duplicates", "brand_voice", "topics", "media_match", "hashtags")
    )
    assert features["duplicates"]["items"][0]["score"] == 1
    assert features["media_match"]["items"][0]["reference_id"] == "coffee-image"
    assert 0 < features["brand_voice"]["items"][0]["score"] <= 1
    assert 2 <= len(features["topics"]["items"]) <= 5
    assert all(row["label"] not in draft for row in features["hashtags"]["items"])
    assert first["features"] == second["features"]
    json.dumps(first, allow_nan=False)


def test_empty_vocabulary_and_unseen_terms_do_not_crash_or_invent_matches():
    data = History(
        [{"id": "1", "text": "!!!", "platform": "x"}],
        ["!!!"] * 5,
        [{"id": "x", "text": "...", "label": "..."}],
        [],
        {},
    )
    assert all(f["status"] == "needs_data" for f in analyze(data, "???", "x")["features"])
    results = {f["id"]: f for f in analyze(history(), "zzzzxyz", "x")["features"]}
    assert results["duplicates"]["items"] == []
    assert results["media_match"]["items"] == []
    assert results["hashtags"]["items"] == []


def predictive_history(constant=False):
    data = history()
    rng = np.random.default_rng(42)
    start = datetime.now(UTC) - timedelta(days=150)
    for i in range(120):
        words = int(rng.integers(5, 60))
        platform = "instagram" if i % 2 else "facebook"
        rate = (
            5.0
            if constant
            else float(np.expm1(0.02 * words + (0.5 if platform == "instagram" else 0.1)))
        )
        data.posts.append(
            {
                "id": str(i),
                "text": "coffee " * words,
                "platform": platform,
                "published": (start + timedelta(days=i)).replace(hour=12),
                "impressions": 10000,
                "engagements": int(rate * 100),
                "rate": rate,
            }
        )
    return data


def test_three_prediction_tools_validate_and_rank_supported_choices():
    results = prediction_features(
        predictive_history(), "coffee " * 30, "instagram", datetime.now(UTC).replace(hour=8)
    )
    assert {f["id"] for f in results} == {"engagement", "posting_time", "channel"}
    assert all(f["status"] == "ready" and f["items"] for f in results)
    assert all(f["diagnostics"]["holdout_mae"] < f["diagnostics"]["baseline_mae"] for f in results)
    assert next(f for f in results if f["id"] == "channel")["items"][0]["label"] == "instagram"


def test_constant_outcomes_fail_baseline_gate_and_unknown_platform_abstains():
    results = prediction_features(
        predictive_history(True), "coffee", "instagram", datetime.now(UTC)
    )
    assert all(f["status"] == "unreliable" and not f["items"] for f in results)
    results = prediction_features(
        predictive_history(), "coffee " * 30, "youtube", datetime.now(UTC)
    )
    assert next(f for f in results if f["id"] == "engagement")["status"] == "needs_data"


def test_isolation_forest_finds_extreme_post_without_fraud_label():
    data = predictive_history(True)
    data.posts[-1].update(impressions=10000000, engagements=2000000, rate=20)
    result = anomaly_feature(data)
    assert result["status"] == "ready"
    assert any(item["reference_id"] == "119" for item in result["items"])
    assert "not evidence of fraud" in result["explanation"]


def forecast_history():
    data = History([], [], [], [], {})
    total = 0
    start = datetime.now(UTC).date() - timedelta(days=34)
    for i in range(35):
        total += 10 + i * 2
        data.daily[start + timedelta(days=i)] = {"stable-post": total}
    return data


def test_recursive_forecast_is_finite_and_validates_against_seasonal_baseline():
    result = forecast_feature(forecast_history())
    assert result["status"] == "ready", result
    assert len(result["items"]) == 7
    assert result["diagnostics"]["holdout_mae"] < result["diagnostics"]["baseline_mae"]
    assert all(item["score"] >= 0 for item in result["items"])
    json.dumps(result, allow_nan=False)


def test_forecast_abstains_on_missing_days_and_counter_resets():
    data = forecast_history()
    del data.daily[min(data.daily)]
    assert forecast_feature(data)["status"] == "needs_data"
    data = forecast_history()
    data.daily[max(data.daily)] = {"stable-post": 0}
    assert forecast_feature(data)["status"] == "needs_data"


def register(client, name):
    return register_account(
        client, email=f"{name}@example.test", organization_name=name, workspace_name=name
    )


def test_endpoint_auth_tenant_isolation_and_validation(client):
    one = register(client, "one")
    two = register(client, "two")
    path = f"/api/v1/workspaces/{one['workspace']['id']}/ml/insights"
    assert client.post(path, headers=bearer(two), json={}).status_code == 404
    client.cookies.clear()
    assert client.post(path, json={}).status_code == 401
    assert client.post(path, headers=bearer(one), json={"draft": "x" * 6001}).status_code == 422
    assert client.post(path, headers=bearer(one), json={"platform": "invalid"}).status_code == 422
    response = client.post(path, headers=bearer(one), json={"draft": "a private draft"})
    assert response.status_code == 200, response.text
    assert len(response.json()["features"]) == 10
    assert "a private draft" not in response.text


def test_loader_uses_seven_day_sample_and_latest_daily_snapshot(client, session):
    user = register(client, "samples")
    uid = uuid.UUID(user["user"]["id"])
    wid = uuid.UUID(user["workspace"]["id"])
    account = SocialAccount(
        workspace_id=wid,
        created_by_user_id=uid,
        platform="instagram",
        display_name="private account",
        external_account_id="private",
        access_token_ref="SECRET TOKEN",
        status="connected",
    )
    session.add(account)
    session.flush()
    published = datetime.now(UTC) - timedelta(days=10)
    session.add(
        PublishJob(
            workspace_id=wid,
            created_by_user_id=uid,
            social_account_id=account.id,
            idempotency_key="post",
            status="published",
            published_at=published,
            external_post_id="post",
            payload={"text": "Coffee caption"},
        )
    )
    for days, impressions, engagements in [(1, 10, 1), (7, 100, 8), (7.2, 120, 9), (9, 150, 10)]:
        session.add(
            PostMetric(
                workspace_id=wid,
                social_account_id=account.id,
                external_post_id="post",
                collected_at=published + timedelta(days=days),
                impressions=impressions,
                engagements=engagements,
            )
        )
    session.add(
        MediaAsset(
            workspace_id=wid,
            created_by_user_id=uid,
            media_type="image",
            asset_role="source",
            status="ready",
            storage_key="private-key",
            filename="coffee.jpg",
            mime_type="image/jpeg",
            sha256="0" * 64,
        )
    )
    session.commit()
    loaded = load_history(session, uid, wid)
    assert len(loaded.posts) == 1
    assert loaded.posts[0]["rate"] == 8
    assert loaded.assets[0]["label"] == "coffee.jpg"
    report = analyze(loaded, "Coffee caption", "instagram")
    assert "SECRET TOKEN" not in json.dumps(report)
    assert "private-key" not in json.dumps(report)


def test_busy_inference_returns_retryable_error(client):
    from aevra_api.api.routes.ml import _inference_slot

    user = register(client, "busy")
    _inference_slot.acquire()
    try:
        response = client.post(
            f"/api/v1/workspaces/{user['workspace']['id']}/ml/insights",
            headers=bearer(user),
            json={},
        )
        assert response.status_code == 429
        assert response.headers["retry-after"] == "5"
    finally:
        _inference_slot.release()


def test_future_training_labels_are_purged_and_out_of_range_drafts_are_withheld():
    data = predictive_history()
    start = datetime.now(UTC) - timedelta(days=2)
    for index, post in enumerate(data.posts):
        post["published"] = start + timedelta(minutes=index)
    results = prediction_features(data, "coffee " * 30, "instagram", datetime.now(UTC))
    assert all(feature["status"] == "needs_data" for feature in results)
    results = prediction_features(
        predictive_history(), "coffee " * 500, "instagram", datetime.now(UTC)
    )
    assert all(feature["status"] == "unreliable" for feature in results)


def test_forecast_detects_individual_counter_reset_hidden_by_total_growth():
    data = forecast_history()
    for index, day in enumerate(sorted(data.daily)):
        data.daily[day]["second"] = 1000 + index * 100
    data.daily[max(data.daily)]["stable-post"] -= 100
    assert forecast_feature(data)["status"] == "needs_data"


def test_saved_variant_hashtag_metadata_is_used(client, session):
    from test_phase_5_6_campaigns import create_brand, create_campaign

    from aevra_api.db.models import ContentVariant

    user = register(client, "tags")
    brand = create_brand(client, user)
    campaign = create_campaign(client, user, brand["id"], ["instagram"])
    wid = uuid.UUID(user["workspace"]["id"])
    for index in range(5):
        session.add(
            ContentVariant(
                workspace_id=wid,
                campaign_id=uuid.UUID(campaign["id"]),
                revision=index + 1,
                platform="instagram",
                caption=f"Morning coffee roast {index}",
                hashtags=[f"#espresso{index}"],
                status="approved",
                generated_by_model="test",
            )
        )
    session.commit()
    data = load_history(session, uuid.UUID(user["user"]["id"]), wid)
    report = analyze(data, "Morning coffee roast", "instagram")
    tags = next(feature for feature in report["features"] if feature["id"] == "hashtags")
    assert tags["status"] == "ready"
    assert any(row["label"].startswith("#espresso") for row in tags["items"])
