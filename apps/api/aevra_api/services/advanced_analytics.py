"""Exploratory visual analytics and uncertainty-aware draft comparisons."""

from collections import defaultdict
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import numpy as np
from sklearn.cluster import KMeans
from sklearn.decomposition import TruncatedSVD
from sklearn.feature_extraction import DictVectorizer
from sklearn.linear_model import Ridge
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from threadpoolctl import threadpool_limits

from aevra_api.services.ml_insights import History, post_vector, prediction_features, utc, vectorize


def content_map(history: History) -> dict:
    rows = history.texts[:500]
    base = {
        "status": "needs_data",
        "points": [],
        "clusters": [],
        "sample_count": len(rows),
        "explained_variance": None,
        "capped": len(history.texts) > 500,
        "explanation": "Add eight distinct captions with varied vocabulary to build a map.",
    }
    if len(rows) < 8:
        return base
    vectorizer, matrix = vectorize([row["text"] for row in rows])
    if matrix is None or matrix.shape[1] < 3:
        return base
    variance = float(
        np.asarray(matrix.power(2).mean(axis=0) - np.square(matrix.mean(axis=0))).sum()
    )
    if variance < 1e-12:
        return base
    projection = TruncatedSVD(n_components=2, random_state=42)
    positions = projection.fit_transform(matrix)
    if not np.isfinite(projection.explained_variance_ratio_).all():
        return base
    count = min(5, max(2, len(rows) // 5), len(np.unique(np.round(positions, 8), axis=0)))
    model = KMeans(n_clusters=count, random_state=42, n_init=10).fit(matrix)
    terms = vectorizer.get_feature_names_out()
    # Independent axis normalization fills the canvas; axes have no outcome meaning.
    low, high = positions.min(axis=0), positions.max(axis=0)
    positions = (positions - low) / np.where(high > low, high - low, 1)
    performance = {post["id"]: post for post in history.posts}
    clusters = [
        {
            "id": int(cluster),
            "label": ", ".join(terms[np.argsort(-model.cluster_centers_[cluster])[:3]]),
            "count": int(np.sum(model.labels_ == cluster)),
        }
        for cluster in sorted(set(model.labels_))
    ]
    points = []
    for i, row in enumerate(rows):
        measured = performance.get(row["id"])
        points.append(
            {
                "id": row["id"],
                "caption": row["text"][:250],
                "platform": row["platform"],
                "cluster": int(model.labels_[i]),
                "x": round(float(positions[i, 0]), 6),
                "y": round(float(positions[i, 1]), 6),
                "engagement_rate": round(measured["rate"], 3) if measured else None,
            }
        )
    return {
        **base,
        "status": "ready",
        "points": points,
        "clusters": clusters,
        "explained_variance": round(float(projection.explained_variance_ratio_.sum()), 4),
        "explanation": "TF-IDF → two-dimensional SVD, with K-means themes. Nearby points "
        "share wording; distance is approximate and axes do not measure quality. "
        "Rates use matched seven-day samples; missing rates are not zero.",
    }


def compare_drafts(history: History, draft_a: str, draft_b: str, platform: str, now: datetime):
    base = {
        "status": "needs_data",
        "prediction_a": None,
        "prediction_b": None,
        "delta": None,
        "delta_range": None,
        "bootstrap_samples": 0,
        "week_blocks": 0,
        "diagnostics": {},
        "explanation": "Enter both drafts to compare estimated engagement rates.",
    }
    if not draft_a.strip() or not draft_b.strip():
        return base
    estimates = []
    for draft in (draft_a, draft_b):
        estimate = next(
            row
            for row in prediction_features(history, draft, platform, now)
            if row["id"] == "engagement"
        )
        if estimate["status"] != "ready":
            return {
                **base,
                "status": estimate["status"],
                "explanation": estimate["explanation"],
                "diagnostics": estimate["diagnostics"],
            }
        estimates.append(estimate)
    try:
        timezone = ZoneInfo(history.timezone)
    except (ZoneInfoNotFoundError, ValueError):
        timezone = ZoneInfo("UTC")
    rows = history.posts
    weeks = defaultdict(list)
    for index, post in enumerate(rows):
        local = utc(post["published"]).astimezone(timezone)
        weeks[local.date() - timedelta(days=local.weekday())].append(index)
    base["week_blocks"] = len(weeks)
    if len(weeks) < 6:
        return {
            **base,
            "explanation": "Collect performance across six calendar weeks "
            "for a block-resampled comparison.",
        }
    vectors = [
        post_vector(row["text"], row["platform"], row["published"], timezone) for row in rows
    ]
    y = np.log1p([row["rate"] for row in rows])
    candidate_vectors = [
        post_vector(draft, platform, now, timezone) for draft in (draft_a, draft_b)
    ]
    rng = np.random.default_rng(42)
    blocks = list(weeks.values())
    deltas = []
    # Resample whole calendar weeks to retain some temporal dependence.
    for _ in range(120):
        indices = [
            index for block in rng.integers(0, len(blocks), len(blocks)) for index in blocks[block]
        ]
        if sum(rows[index]["platform"] == platform for index in indices) < 10:
            continue
        model = make_pipeline(DictVectorizer(sparse=False), StandardScaler(), Ridge(alpha=10))
        model.fit([vectors[index] for index in indices], y[indices])
        predictions = np.expm1(np.clip(model.predict(candidate_vectors), 0, 12))
        deltas.append(float(predictions[1] - predictions[0]))
        if len(deltas) == 60:
            break
    if len(deltas) < 30:
        return {
            **base,
            "explanation": "Too few supported resamples; collect more platform history.",
        }
    lower, upper = np.quantile(deltas, [0.1, 0.9])
    a, b = [estimate["items"][0]["score"] for estimate in estimates]
    return {
        **base,
        "status": "ready",
        "prediction_a": a,
        "prediction_b": b,
        "delta": round(b - a, 4),
        "delta_range": [round(float(lower), 4), round(float(upper), 4)],
        "bootstrap_samples": len(deltas),
        "diagnostics": estimates[0]["diagnostics"],
        "explanation": "B minus A in engagements per 100 impressions, holding platform and "
        "posting time fixed. The 10th–90th percentile range reflects week-block "
        "model resampling, not a calibrated outcome interval or causal uplift. "
        "This model uses caption length, hashtags, links and question marks; "
        "equivalent structural edits can produce identical estimates. "
        "Confirm any advantage with a controlled publishing experiment.",
    }


def ks_distance(a, b):
    knots = np.unique(np.concatenate((a, b)))
    return float(
        np.max(
            np.abs(
                np.searchsorted(np.sort(a), knots, side="right") / len(a)
                - np.searchsorted(np.sort(b), knots, side="right") / len(b)
            )
        )
    )


def data_quality(history: History, platform: str, now: datetime):
    days = [now.date() - timedelta(days=offset) for offset in reversed(range(35))]
    timeline = [
        {"date": day.isoformat(), "observed_posts": len(history.daily.get(day, {}))} for day in days
    ]
    available = sum(point["observed_posts"] > 0 for point in timeline)
    eligible = history.quality.get("mature_published_posts")
    matched = history.quality.get("mature_matched_posts")
    coverage = round(matched / eligible * 100, 1) if eligible else None
    latest = history.quality.get("latest_metric_at")
    age = (
        max(0, (now - utc(datetime.fromisoformat(latest))).total_seconds() / 3600)
        if latest
        else None
    )
    end = now - timedelta(days=8)
    middle, start = end - timedelta(days=14), end - timedelta(days=28)
    previous = np.array(
        [
            post["rate"]
            for post in history.posts
            if post["platform"] == platform and start <= utc(post["published"]) < middle
        ]
    )
    recent = np.array(
        [
            post["rate"]
            for post in history.posts
            if post["platform"] == platform and middle <= utc(post["published"]) < end
        ]
    )
    drift = {
        "status": "needs_data",
        "previous_samples": len(previous),
        "recent_samples": len(recent),
        "previous_start": start.isoformat(),
        "recent_start": middle.isoformat(),
        "window_end": end.isoformat(),
        "ks_distance": None,
        "permutation_p": None,
        "previous_median": None,
        "recent_median": None,
        "explanation": "Collect ten comparable posts in each of two consecutive "
        "14-day publishing windows on the selected platform. Windows end "
        "eight days ago so outcomes can mature.",
    }
    if len(previous) >= 10 and len(recent) >= 10:
        observed = ks_distance(previous, recent)
        pooled = np.concatenate((previous, recent))
        rng = np.random.default_rng(42)
        extreme = 0
        for _ in range(199):
            shuffled = rng.permutation(pooled)
            extreme += ks_distance(shuffled[: len(previous)], shuffled[len(previous) :]) >= observed
        p = (extreme + 1) / 200
        drift.update(
            status="difference_detected" if p < 0.05 else "no_clear_difference",
            ks_distance=round(observed, 4),
            permutation_p=p,
            previous_median=round(float(np.median(previous)), 3),
            recent_median=round(float(np.median(recent)), 3),
            explanation="Two-sample KS distance with 199 label permutations, including "
            "ties. An exploratory distribution check, not proof of model drift "
            "or its cause. Posts may be dependent and repeated monitoring "
            "can produce false alarms; investigate audience and content mix.",
        )
    return {
        "coverage_percent": coverage,
        "mature_posts": eligible,
        "matched_posts": matched,
        "metric_samples": history.quality.get("metric_samples"),
        "latest_metric_at": latest,
        "freshness_hours": round(age, 1) if age is not None else None,
        "observed_days": available,
        "missing_days": 35 - available,
        "timeline": timeline,
        "drift": drift,
        "history_capped": history.truncated,
        "explanation": "Coverage is measured seven-day outcomes / sampled posts at least "
        "eight days old. Blank days mean missing observations, not zero "
        "engagement. Calendar is UTC and covers 35 days, including today.",
    }


def advanced_analyze(history: History, draft_a: str, draft_b: str, platform: str, now=None):
    now = utc(now or datetime.now(UTC))
    with threadpool_limits(limits=1):
        return {
            "version": "vae-advanced-v1",
            "generated_at": now.isoformat(),
            "platform": platform,
            "timezone": history.timezone,
            "content_map": content_map(history),
            "comparison": compare_drafts(history, draft_a, draft_b, platform, now),
            "data_quality": data_quality(history, platform, now),
            "audit": {
                "scope": "Current workspace only",
                "external_requests": 0,
                "automatic_actions": False,
                "drafts_saved": False,
                "history_capped": history.truncated,
            },
        }
