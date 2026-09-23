# VAE ML features and implementation audit

Date: 2026-09-23. Model contract: `vae-ml-v1`.

Implemented in the API, web dashboard and Flutter app. These are local statistical ML models fitted to each workspace's own stored data, not additional LLM prompts. They run on explicit request, return reviewable suggestions, and do not modify content, schedules, accounts, payments or permissions.

## Ten features

| Feature | Where it helps | Model and data | Activation requirements |
|---|---|---|---|
| 1. Duplicate-copy detection | Catch repetitive drafts before publishing | Learned TF-IDF vocabulary/IDF and cosine neighbours against approved or published copy | Draft and at least one saved text; matches shown above 0.65 similarity |
| 2. Brand-language match | Compare a draft with previously approved wording | TF-IDF centroid of approved workspace captions | Draft and five distinct approved captions |
| 3. Topic discovery | Review content themes and plan variety | TF-IDF plus deterministic K-means, up to five clusters | Eight distinct saved captions |
| 4. Media matching | Find relevant existing assets for a brief | TF-IDF ranking over filenames and generation prompts | Draft and at least one ready asset with useful metadata |
| 5. Hashtag suggestions | Reuse relevant tags from the workspace's own content | Similarity-weighted nearest-neighbour voting; excludes tags already in the draft | Five tagged captions and a draft; includes separately stored variant hashtags |
| 6. Engagement prediction | Estimate a draft's approximate seven-day engagement rate | Ridge regression over caption structure, platform and cyclical posting-time features | At least 30 comparable posts, 20 matured training labels, 10 samples on the target platform, and successful chronological validation |
| 7. Posting-time suggestions | Compare supported upcoming time slots | Candidate ranking with the validated engagement model and workspace timezone | Same model requirements; candidate hours need at least three historical posts |
| 8. Channel recommendations | Compare historical platform fit for a draft | Validated ridge model evaluated on supported platforms | Same model requirements plus at least ten samples on each of two platforms |
| 9. Performance anomalies | Identify posts worth inspecting | Isolation forest over log impressions, engagements and rate, separately per platform | Twenty comparable posts per platform |
| 10. Seven-day engagement forecast | Estimate near-term engagement on existing tracked posts | Autoregressive ridge using previous day, seven-day mean and weekly lag | 35 consecutive daily snapshots for a stable post cohort, fresh telemetry, no counter resets, and successful recursive holdout validation |

“Comparable posts” have positive impressions and a sample collected 6–8 days after publication. The closest sample to seven days is selected. Engagement rate is engagements per 100 impressions; it is not a probability and is not necessarily capped at 100.

## Access and integration

- Web: **ML insights** in the creator sidebar/command menu, or **Analytics → Explore ML insights**. Existing draft text seeds the web analysis form.
- Flutter: **Analytics → Explore ML insights**.
- API: authenticated `POST /api/v1/workspaces/{workspace_id}/ml/insights` with `draft` (optional, maximum 6,000 characters) and a supported `platform`.
- Empty drafts still allow topic discovery, anomaly analysis and forecasting.
- Every card exposes the method, sample count, minimum requirements, result status and relevant validation diagnostics. Editing the input marks previous results stale.
- The response includes model version, time, timezone, training scope, data caps and audit notes. New workspaces receive `needs_data`; failed validation returns `unreliable` with predictions withheld.

## Audit findings and controls

| Area | Finding / implemented control | Remaining limitation |
|---|---|---|
| Tenant isolation | Active workspace membership is checked before querying any ML history; every query filters workspace ID. Cross-tenant requests return 404. | This is membership-level reporting, not separate models for each brand inside a shared workspace. |
| Privacy | No external AI calls, draft persistence, serialized model files, or training across customers. Responses do not include OAuth credentials or storage keys. | Authorized members can see matching excerpts and filenames from their own workspace. Deployment request-body logging must remain disabled for drafts. |
| Time leakage | Holdout is chronological and preprocessing is fitted only on training rows. Training labels observed after the holdout starts are purged. | A single holdout is a screening check, not broad production validation or a calibrated confidence interval. |
| Label quality | Uses comparable post age instead of mixing one-day and lifetime metrics; future-dated metric samples are excluded. | Different accounts, audience sizes and 6–8-day collection differences can still confound outcomes. |
| Counter quality | Latest sample per post/day, stable forecast cohort, missing days withheld and individual counter resets detected. | Forecast excludes future posts and needs reliable daily collection. |
| Model usefulness | Prediction MAE must beat a training-median baseline; recursive forecast MAE must beat the prior week's daily values. Out-of-range draft lengths are withheld. | Synthetic success does not establish real customer uplift. Other distribution shifts remain possible. |
| Explainability | Shows algorithms, sample sizes, data requirements, MAE/baseline diagnostics and explicit limitations. | Similarity and anomaly scores are not probabilities or fraud/plagiarism verdicts. |
| Resource bounds | At most 500 published jobs, 500 approved captions, 500 ready assets and 8,000 metric samples from the last year. TF-IDF vocabulary capped at 2,500 features. One concurrent inference per API worker, one numerical thread, retryable 429 on contention. | No shared model cache, global distributed quota or production load-test evidence. Models refit per analysis. |
| Side effects | Analysis performs reads and in-memory computation only; no scheduler, publisher, payment or account actions. | Suggestions require review and manual application. |
| UI behavior | Loading/error/empty/withheld states, stale-input notice, responsive cards and expandable validation details on web and Flutter. | Native physical-device testing was not performed. |

No unresolved access-control failure was found in the tests performed. This is an implementation self-audit, not an independent security certification.

## Verification evidence

- API regression suite: **80 tests passed**, including **14 ML-specific tests**.
- ML-specific tests cover all ten feature paths, empty/punctuation-only/unseen vocabularies, deterministic text results, unsupported platforms, baseline rejection, delayed-label purging, out-of-range drafts, outliers, recursive forecasts, missing days, counter resets, auth, tenant boundaries, input limits, stored hashtag metadata and inference contention.
- Web formatting, TypeScript and optimized Next.js production build pass.
- Browser: real ML engine with synthetic local fixture; ten rendered results, stale-input notice, and 390px responsive layout checked. No live tenant writes or provider calls.
- Flutter: **analysis clean; 11 tests passed**. Added a 320px widget test covering analysis submission, withheld predictions and stale-input messaging.
- Synthetic local benchmark: 120 posts, 10 text examples and 35 daily snapshots; all ten feature paths returned ready in **0.415 seconds** after import. Not a cold-start, maximum-load, remote-host or production benchmark.
- Synthetic prediction validation: 89 training samples, 7 purged samples and 24 holdout samples; MAE **0.0393** versus median baseline **0.758** engagements per 100 impressions.
- Synthetic recursive forecast: seven-day MAE **5.733** versus weekly baseline **14.0** engagements. One fixed synthetic post cohort.

## Deployment and operating limits

Install the updated API dependencies and deploy API, web and mobile changes together. No schema migration is required. Tested locally with scikit-learn 1.9.1, NumPy 2.5.3 and SciPy 1.18.1. No model download, external ML account or new secret is required.

For real-world validation, collect enough dated metrics through existing analytics ingestion, then evaluate on representative tenant history. Retain the withholding gates. Monitor inference latency, 429s, data freshness and holdout performance before considering automated workflows. Current implementation deliberately contains no auto-publishing integration.

Text models measure lexical similarity, not semantic understanding, factual correctness, sentiment, image pixels or live trends. Brand affinity is a vocabulary match, not a compliance check. Platform/time rankings are observational, not evidence that changing a platform or time causes improved engagement.

Implementation entry points: `apps/api/aevra_api/services/ml_insights.py`, `apps/api/aevra_api/api/routes/ml.py`, `apps/web/components/ml-studio.tsx`, `apps/mobile/lib/screens/ml_insights_screen.dart`.

Algorithm reference: [scikit-learn TF-IDF documentation](https://scikit-learn.org/stable/modules/generated/sklearn.feature_extraction.text.TfidfVectorizer.html).
