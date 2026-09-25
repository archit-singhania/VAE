"""Workspace-local, bounded ML inference. Models are fitted in memory, never pickled.

No external provider calls, cross-tenant training, or automated publishing decisions.
"""

import math
import re
import uuid
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import numpy as np
from sklearn.cluster import KMeans
from sklearn.ensemble import IsolationForest
from sklearn.feature_extraction import DictVectorizer
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_absolute_error
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sqlalchemy import select
from sqlalchemy.orm import Session
from threadpoolctl import threadpool_limits

from aevra_api.db.models import ContentVariant, MediaAsset, PostMetric, PublishJob, SocialAccount
from aevra_api.domain.errors import NotFoundError
from aevra_api.repositories.tenancy import TenancyRepository

VERSION = "vae-ml-v1"
MAX_POSTS = 500
MAX_METRICS = 8000
NAMES = {
    "duplicates": ("Duplicate-copy detection", "TF-IDF cosine nearest neighbours"),
    "brand_voice": ("Brand-language match", "Approved-copy TF-IDF centroid"),
    "topics": ("Topic discovery", "TF-IDF + K-means"),
    "media_match": ("Media matching", "Metadata TF-IDF nearest neighbours"),
    "hashtags": ("Hashtag suggestions", "Similarity-weighted neighbour voting"),
    "engagement": ("Engagement prediction", "Regularized ridge regression"),
    "posting_time": ("Posting-time suggestions", "Ridge model candidate ranking"),
    "channel": ("Channel recommendations", "Ridge model platform ranking"),
    "anomalies": ("Performance anomalies", "Isolation forest"),
    "forecast": ("Seven-day engagement forecast", "Autoregressive ridge regression"),
}


def utc(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


@dataclass
class History:
    texts: list[dict]
    approved: list[str]
    assets: list[dict]
    posts: list[dict]
    daily: dict
    timezone: str = "UTC"
    truncated: bool = False
    quality: dict = field(default_factory=dict)


def load_history(session: Session, user_id: uuid.UUID, workspace_id: uuid.UUID) -> History:
    workspace = TenancyRepository(session).get_workspace_for_user(user_id, workspace_id)
    if workspace is None:
        raise NotFoundError("Workspace not found")
    jobs = session.execute(
        select(PublishJob, SocialAccount.platform)
        .join(SocialAccount, SocialAccount.id == PublishJob.social_account_id)
        .where(
            PublishJob.workspace_id == workspace_id,
            PublishJob.status.in_(("published", "verified")),
            PublishJob.published_at.is_not(None),
        )
        .order_by(PublishJob.published_at.desc(), PublishJob.id)
        .limit(MAX_POSTS + 1)
    ).all()
    variants = session.scalars(
        select(ContentVariant)
        .where(ContentVariant.workspace_id == workspace_id, ContentVariant.status == "approved")
        .order_by(ContentVariant.created_at.desc(), ContentVariant.id)
        .limit(501)
    ).all()
    assets = session.scalars(
        select(MediaAsset)
        .where(MediaAsset.workspace_id == workspace_id, MediaAsset.status == "ready")
        .order_by(MediaAsset.created_at.desc(), MediaAsset.id)
        .limit(501)
    ).all()
    # Keep the nearest seven-day sample per post without loading an unbounded history.
    recent = datetime.now(UTC) - timedelta(days=365)
    samples = session.execute(
        select(
            PostMetric.social_account_id,
            PostMetric.external_post_id,
            PostMetric.collected_at,
            PostMetric.impressions,
            PostMetric.engagements,
        )
        .where(
            PostMetric.workspace_id == workspace_id,
            PostMetric.collected_at >= recent,
            PostMetric.collected_at <= datetime.now(UTC),
        )
        .order_by(PostMetric.collected_at.desc(), PostMetric.id.desc())
        .limit(MAX_METRICS + 1)
    ).all()
    by_post = defaultdict(list)
    daily = defaultdict(dict)
    for account, post, collected, impressions, engagements in samples[:MAX_METRICS]:
        when = utc(collected)
        by_post[(account, post)].append((when, impressions, engagements))
        day = when.date()
        key = f"{account}:{post}"
        # Descending sample order makes the first sample the last one that day.
        daily[day].setdefault(key, engagements)
    texts, posts = [], []
    mature_jobs = 0
    mature_matches = 0
    now = datetime.now(UTC)
    seen_posts = set()
    for job, platform in jobs[:MAX_POSTS]:
        key = (job.social_account_id, job.external_post_id)
        if job.external_post_id and key in seen_posts:
            continue
        seen_posts.add(key)
        text = str((job.payload or {}).get("text") or "")[:6000]
        published = utc(job.published_at)
        mature = published <= now - timedelta(days=8)
        mature_jobs += int(mature)
        texts.append({"id": str(job.id), "text": text, "platform": platform})
        candidates = [
            sample
            for sample in by_post[key]
            if 6 <= (sample[0] - published).total_seconds() / 86400 <= 8 and sample[1] > 0
        ]
        if candidates:
            mature_matches += int(mature)
            sample = min(
                candidates, key=lambda row: abs((row[0] - published).total_seconds() - 7 * 86400)
            )
            posts.append(
                {
                    "id": str(job.id),
                    "text": text,
                    "platform": platform,
                    "published": published,
                    "observed_at": sample[0],
                    "impressions": sample[1],
                    "engagements": sample[2],
                    "rate": sample[2] / sample[1] * 100,
                }
            )
    texts.extend(
        {
            "id": str(v.id),
            "text": (v.caption + " " + " ".join(v.hashtags or []))[:6000],
            "platform": v.platform,
        }
        for v in variants[:500]
    )
    # Exact duplicate variants must not overweight the text models.
    unique = {row["text"].strip().casefold(): row for row in reversed(texts) if row["text"].strip()}
    return History(
        texts=list(unique.values()),
        approved=list(dict.fromkeys(v.caption[:6000] for v in variants[:500])),
        assets=[
            {"id": str(a.id), "text": f"{a.filename} {a.prompt or ''}"[:6000], "label": a.filename}
            for a in assets[:500]
        ],
        posts=sorted(posts, key=lambda row: (row["published"], row["id"])),
        daily=dict(daily),
        timezone=workspace.timezone,
        quality={
            "mature_published_posts": mature_jobs,
            "mature_matched_posts": mature_matches,
            "metric_samples": min(len(samples), MAX_METRICS),
            "latest_metric_at": utc(samples[0][2]).isoformat() if samples else None,
        },
        truncated=(
            len(jobs) > MAX_POSTS
            or len(variants) > 500
            or len(assets) > 500
            or len(samples) > MAX_METRICS
        ),
    )


def result(key, count, minimum, reason, items=None, diagnostics=None, status=None):
    return {
        "id": key,
        "title": NAMES[key][0],
        "method": NAMES[key][1],
        "status": status or ("ready" if items is not None else "needs_data"),
        "sample_count": count,
        "minimum_samples": minimum,
        "explanation": reason,
        "items": items or [],
        "diagnostics": diagnostics or {},
    }


def item(label, detail, score=None, reference_id=None):
    return {"label": label, "detail": detail, "score": score, "reference_id": reference_id}


def vectorize(texts):
    vectorizer = TfidfVectorizer(max_features=2500, ngram_range=(1, 2), sublinear_tf=True)
    try:
        matrix = vectorizer.fit_transform(texts)
    except ValueError:  # Empty / punctuation-only corpora are valid cold starts.
        return None, None
    return vectorizer, matrix


def text_features(history: History, draft: str):
    output = []
    texts = [row["text"] for row in history.texts]
    vectorizer, matrix = vectorize(texts) if texts else (None, None)
    if vectorizer is not None and draft.strip():
        similarities = cosine_similarity(vectorizer.transform([draft]), matrix)[0]
        ranked = np.argsort(-similarities, kind="stable")[:5]
        output.append(
            result(
                "duplicates",
                len(texts),
                1,
                "Lexical overlap with saved copy; similarity is not a plagiarism verdict.",
                [
                    item(
                        history.texts[i]["text"][:150],
                        "Similar saved copy",
                        round(float(similarities[i]), 3),
                        history.texts[i]["id"],
                    )
                    for i in ranked
                    if similarities[i] >= 0.65
                ],
            )
        )
    else:
        output.append(
            result(
                "duplicates", len(texts), 1, "Enter a draft and save at least one text with words."
            )
        )

    voice, voice_matrix = (
        vectorize(history.approved) if len(history.approved) >= 5 else (None, None)
    )
    if voice is not None and draft.strip():
        centroid = np.asarray(voice_matrix.mean(axis=0))
        score = float(cosine_similarity(voice.transform([draft]), centroid)[0, 0])
        output.append(
            result(
                "brand_voice",
                len(history.approved),
                5,
                "Vocabulary affinity to approved workspace copy; not a tone "
                "or compliance guarantee.",
                [
                    item(
                        "Approved-language affinity",
                        "Cosine similarity from 0 to 1",
                        round(score, 3),
                    )
                ],
            )
        )
    else:
        output.append(
            result(
                "brand_voice",
                len(history.approved),
                5,
                "Enter a draft and approve five distinct captions to learn a reference voice.",
            )
        )

    if matrix is not None and len(texts) >= 8:
        k = min(5, max(2, len(texts) // 4))
        clustering = KMeans(n_clusters=k, random_state=42, n_init=10).fit(matrix)
        terms = vectorizer.get_feature_names_out()
        clusters = []
        for cluster in sorted(set(clustering.labels_)):
            top = np.argsort(-clustering.cluster_centers_[cluster])[:4]
            clusters.append(
                item(
                    ", ".join(terms[top]),
                    f"{int(np.sum(clustering.labels_ == cluster))} saved texts",
                )
            )
        output.append(
            result(
                "topics",
                len(texts),
                8,
                "Unsupervised themes inferred from saved wording; labels may need editing.",
                clusters,
            )
        )
    else:
        output.append(
            result("topics", len(texts), 8, "Save eight distinct captions to discover themes.")
        )

    media, media_matrix = (
        vectorize([a["text"] for a in history.assets]) if history.assets else (None, None)
    )
    if media is not None and draft.strip():
        scores = cosine_similarity(media.transform([draft]), media_matrix)[0]
        matches = [
            item(
                history.assets[i]["label"],
                "Filename / prompt relevance",
                round(float(scores[i]), 3),
                history.assets[i]["id"],
            )
            for i in np.argsort(-scores, kind="stable")[:5]
            if scores[i] > 0
        ]
        output.append(
            result(
                "media_match",
                len(history.assets),
                1,
                "Matches media metadata, not image pixels. Review the asset before using it.",
                matches,
            )
        )
    else:
        output.append(
            result(
                "media_match",
                len(history.assets),
                1,
                "Enter a draft and add media with descriptive filenames or prompts.",
            )
        )

    tagged = [row for row in history.texts if re.search(r"#\w+", row["text"])]
    clean = [re.sub(r"#\w+", "", row["text"]) for row in tagged]
    tags_vectorizer, tags_matrix = vectorize(clean) if len(tagged) >= 5 else (None, None)
    if tags_vectorizer is not None and draft.strip():
        scores = cosine_similarity(tags_vectorizer.transform([draft]), tags_matrix)[0]
        votes = Counter()
        existing = set(re.findall(r"#\w+", draft.casefold()))
        for i in np.argsort(-scores, kind="stable")[:10]:
            if scores[i] < 0.1:
                continue
            for tag in set(re.findall(r"#\w+", tagged[i]["text"].casefold())) - existing:
                votes[tag] += float(scores[i])
        output.append(
            result(
                "hashtags",
                len(tagged),
                5,
                "Tags learned from similar saved captions; not live trending hashtags.",
                [
                    item(tag, "Similarity-weighted relevance", round(weight, 3))
                    for tag, weight in votes.most_common(8)
                ],
            )
        )
    else:
        output.append(
            result(
                "hashtags",
                len(tagged),
                5,
                "Enter a draft and save five captions containing hashtags.",
            )
        )
    return output


def post_vector(text, platform, when, timezone):
    local = utc(when).astimezone(timezone)
    return {
        "platform": platform,
        "words": len(text.split()),
        "characters": len(text),
        "hashtags": len(re.findall(r"#\w+", text)),
        "links": len(re.findall(r"https?://", text)),
        "questions": text.count("?"),
        "hour_sin": math.sin(local.hour * math.tau / 24),
        "hour_cos": math.cos(local.hour * math.tau / 24),
        "day_sin": math.sin(local.weekday() * math.tau / 7),
        "day_cos": math.cos(local.weekday() * math.tau / 7),
    }


def prediction_features(history: History, draft, platform, now):
    posts = history.posts
    keys = ("engagement", "posting_time", "channel")
    if len(posts) < 30 or not draft.strip():
        return [
            result(
                key,
                len(posts),
                30,
                "Enter a draft and collect 30 published posts with positive "
                "impressions and a metric sample 6–8 days after publishing.",
            )
            for key in keys
        ]
    try:
        timezone = ZoneInfo(history.timezone)
    except (ZoneInfoNotFoundError, ValueError):
        timezone = ZoneInfo("UTC")
    vectors = [post_vector(p["text"], p["platform"], p["published"], timezone) for p in posts]
    y = np.array([p["rate"] for p in posts])
    split = int(len(posts) * 0.8)

    # Split chronologically before fitting preprocessing to avoid holdout leakage.
    def model():
        return make_pipeline(DictVectorizer(sparse=False), StandardScaler(), Ridge(alpha=10))

    cutoff = posts[split]["published"]
    train_indices = [
        i
        for i in range(split)
        if posts[i].get("observed_at", posts[i]["published"] + timedelta(days=8)) <= cutoff
    ]
    if len(train_indices) < 20:
        return [
            result(
                key,
                len(train_indices),
                20,
                "Need 20 matured training posts before the holdout publishing dates.",
            )
            for key in keys
        ]
    train_vectors = [vectors[i] for i in train_indices]
    train_y = y[train_indices]
    estimator = model().fit(train_vectors, np.log1p(train_y))
    predicted = np.maximum(0, np.expm1(np.clip(estimator.predict(vectors[split:]), 0, 12)))
    mae = float(mean_absolute_error(y[split:], predicted))
    baseline = float(mean_absolute_error(y[split:], np.repeat(np.median(train_y), len(y) - split)))
    diagnostics = {
        "holdout_mae": round(mae, 4),
        "baseline_mae": round(baseline, 4),
        "train_samples": len(train_indices),
        "purged_training_samples": split - len(train_indices),
        "test_samples": len(posts) - split,
        "unit": "engagements per 100 impressions at approximately seven days",
    }
    if baseline <= 0 or mae >= baseline:
        return [
            result(
                key,
                len(posts),
                30,
                "Chronological validation did not beat the median baseline; "
                "predictions are withheld.",
                diagnostics=diagnostics,
                status="unreliable",
            )
            for key in keys
        ]
    word_counts = [len(p["text"].split()) for p in posts]
    if not min(word_counts) <= len(draft.split()) <= max(word_counts):
        return [
            result(
                key,
                len(posts),
                30,
                "Draft length is outside the observed training range; prediction withheld.",
                diagnostics=diagnostics,
                status="unreliable",
            )
            for key in keys
        ]
    estimator = model().fit(vectors, np.log1p(y))
    counts = Counter(p["platform"] for p in posts)

    def predict(target_platform, when):
        value = estimator.predict([post_vector(draft, target_platform, when, timezone)])[0]
        return round(float(max(0, np.expm1(np.clip(value, 0, 12)))), 3)

    output = []
    if counts[platform] >= 10:
        output.append(
            result(
                "engagement",
                len(posts),
                30,
                "Experimental seven-day engagement-rate estimate from "
                "caption structure, platform and timing; not a guarantee.",
                [
                    item(
                        platform,
                        "Estimated engagements per 100 impressions",
                        predict(platform, now),
                    )
                ],
                diagnostics,
            )
        )
        # Rank only local hours actually supported by >=3 observations on this platform.
        hours = Counter(
            utc(p["published"]).astimezone(timezone).hour
            for p in posts
            if p["platform"] == platform
        )
        candidates = []
        for offset in range(7):
            for hour, count in hours.items():
                local = now.astimezone(timezone).replace(
                    hour=hour, minute=0, second=0, microsecond=0
                ) + timedelta(days=offset)
                if count >= 3 and local > now.astimezone(timezone):
                    candidates.append((predict(platform, local), local.isoformat(), count))
        output.append(
            result(
                "posting_time",
                len(posts),
                30,
                f"Candidate ranking in {timezone.key}; observational "
                "associations, not causal uplift. Only supported hours are considered.",
                [
                    item(when, f"{count} historical posts at this hour; estimated rate", value)
                    for value, when, count in sorted(candidates, reverse=True)[:5]
                ]
                if candidates
                else None,
                diagnostics,
            )
        )
    else:
        output.extend(
            result(
                key,
                counts[platform],
                10,
                f"Collect ten seven-day performance samples on {platform}.",
            )
            for key in ("engagement", "posting_time")
        )
    supported = [name for name, count in counts.items() if count >= 10]
    output.append(
        result(
            "channel",
            len(posts),
            30,
            "Platform comparison is observational; audience sizes and "
            "account differences can confound it. Requires ten samples on each of two platforms.",
            [
                item(name, f"{counts[name]} posts; estimated engagement rate", predict(name, now))
                for name in sorted(supported, key=lambda name: -predict(name, now))
            ]
            if len(supported) >= 2
            else None,
            diagnostics,
        )
    )
    return output


def anomaly_feature(history):
    groups = defaultdict(list)
    for post in history.posts:
        groups[post["platform"]].append(post)
    anomalies = []
    eligible = 0
    for platform, posts in groups.items():
        if len(posts) < 20:
            continue
        eligible += len(posts)
        x = np.log1p([[p["impressions"], p["engagements"], p["rate"]] for p in posts])
        model = IsolationForest(
            n_estimators=100, contamination="auto", random_state=42, n_jobs=1
        ).fit(x)
        scores = model.decision_function(x)
        for i in np.argsort(scores)[:5]:
            if scores[i] < 0:
                anomalies.append(
                    item(
                        posts[i]["text"][:100] or "Published post",
                        f"Unusual seven-day metrics on {platform}; inspect collection and content.",
                        round(float(-scores[i]), 4),
                        posts[i]["id"],
                    )
                )
    return result(
        "anomalies",
        eligible,
        20,
        "Requires 20 comparable posts per platform. An outlier is not "
        "evidence of fraud or a platform penalty.",
        sorted(anomalies, key=lambda row: -row["score"])[:8] if eligible else None,
    )


def forecast_feature(history):
    days = sorted(history.daily)
    # Require a consecutive window and a fixed cohort to avoid turning missing telemetry into zero.
    if days:
        end = days[-1]
        days = [end - timedelta(days=offset) for offset in reversed(range(35))]
    if len(days) < 35 or any(day not in history.daily for day in days):
        return result(
            "forecast",
            len(history.daily),
            35,
            "Collect 35 consecutive days of daily snapshots for the same "
            "posts. Missing days are not treated as zero.",
        )
    cohort = set.intersection(*(set(history.daily[day]) for day in days))
    if not cohort:
        return result("forecast", 35, 35, "No stable post cohort across the daily observations.")
    if (datetime.now(UTC).date() - days[-1]).days > 2:
        return result("forecast", 35, 35, "Daily telemetry is stale; collect a recent snapshot.")
    cumulative = [sum(history.daily[day][key] for key in cohort) for day in days]
    increments = np.diff(cumulative).astype(float)
    counter_reset = any(
        history.daily[later][key] < history.daily[earlier][key]
        for earlier, later in zip(days, days[1:], strict=False)
        for key in cohort
    )
    if counter_reset:
        return result(
            "forecast", 35, 35, "Counters decreased; resolve metric resets before forecasting."
        )

    def features(values):
        return [values[-1], float(np.mean(values[-7:])), values[-7]]

    x = [features(increments[:i]) for i in range(7, len(increments))]
    y = increments[7:]
    split = len(x) - 7

    def model():
        return make_pipeline(StandardScaler(), Ridge(alpha=10))

    estimator = model().fit(x[:split], y[:split])
    # Recursive holdout matches the seven-step forecasting task (no future lags).
    history_values = list(increments[: 7 + split])
    predicted = []
    for _ in range(7):
        value = max(0, float(estimator.predict([features(history_values)])[0]))
        predicted.append(value)
        history_values.append(value)
    mae = float(mean_absolute_error(y[split:], predicted))
    baseline = float(mean_absolute_error(y[split:], increments[split : split + 7]))
    diagnostics = {
        "holdout_mae": round(mae, 3),
        "baseline_mae": round(baseline, 3),
        "cohort_posts": len(cohort),
        "test_days": 7,
    }
    if baseline <= 0 or mae >= baseline:
        return result(
            "forecast",
            35,
            35,
            "Seven-day recursive validation did not beat last week's daily "
            "values; forecast withheld.",
            diagnostics=diagnostics,
            status="unreliable",
        )
    estimator = model().fit(x, y)
    values = list(increments)
    forecast = []
    for offset in range(1, 8):
        value = max(0, float(estimator.predict([features(values)])[0]))
        forecast.append(
            item(
                (days[-1] + timedelta(days=offset)).isoformat(),
                "Estimated new engagements for the fixed observed post cohort",
                round(value, 1),
            )
        )
        values.append(value)
    return result(
        "forecast",
        35,
        35,
        "Experimental forecast for existing tracked posts only; excludes "
        "future posts and audience changes.",
        forecast,
        diagnostics,
    )


def analyze(history: History, draft: str, platform: str, now=None):
    now = now or datetime.now(UTC)
    with threadpool_limits(limits=1):
        features = text_features(history, draft)
        features.extend(prediction_features(history, draft, platform, now))
        features.append(anomaly_feature(history))
        features.append(forecast_feature(history))
    return {
        "model_version": VERSION,
        "generated_at": now.isoformat(),
        "timezone": history.timezone,
        "features": features,
        "audit": {
            "training_scope": "Current workspace only",
            "external_requests": 0,
            "automatic_actions": False,
            "models_persisted": False,
            "history_capped": history.truncated,
            "limits": {
                "published_posts": MAX_POSTS,
                "approved_captions": 500,
                "media_assets": 500,
                "metric_samples": MAX_METRICS,
            },
            "notes": [
                "Suggestions require human review.",
                "Text features use lexical statistics, not semantic understanding.",
                "Predictive features use chronological holdouts and abstain "
                "if they do not beat a baseline.",
                "No production accuracy claims until evaluated on representative workspace data.",
            ],
        },
    }
