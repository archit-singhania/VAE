# VAE ML features and implementation audit

Date: 2026-09-24. Model contracts: `vae-ml-v1` and `vae-advanced-v1`.

All thirteen features are implemented in the API, web dashboard and Flutter app. These are local statistical ML models fitted to each workspace's own stored data, not additional LLM prompts. They run on explicit request, return reviewable suggestions, and do not modify content, schedules, accounts, payments or permissions.

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

## Three advanced features (11–13)

| Feature | What it shows | Method | Safeguard |
|---|---|---|---|
| 11. Content-performance map | Explore up to 500 saved captions, their wording themes, platform and measured seven-day outcomes | TF-IDF, two-dimensional TruncatedSVD and deterministic K-means | Map axes show lexical proximity and retained variance; position is explicitly not quality. Zero outcome and missing outcome are different. |
| 12. Draft comparison lab | Compare two drafts at the same platform and posting time | The validated Ridge model estimates rates, then 60 deterministic week-block resamples show the central 10th–90th percentile delta range | Requires the existing holdout gates, six weeks and at least 30 valid resamples. This is model resampling, not a calibrated future interval or causal lift. It points out structural-caption features and asks users to confirm with a controlled test. |
| 13. Data health and distribution shift | Inspect seven-day label coverage, collection freshness, 35-day observation gaps and recent platform outcome distributions | Matched mature publish jobs, UTC daily observation counts, two 14-day outcome windows, KS distance and 199 label permutations | Requires at least ten platform outcomes per period. Repeated monitoring, dependent posts and confounding limit the permutation interpretation. An unobserved day is not zero engagement. |

The advanced API is authenticated at `POST /api/v1/workspaces/{workspace_id}/ml/advanced`. It returns the three independently status-labeled sections under the same workspace and inference bounds. The web table supports selecting map points without a pointer; Flutter exposes point selection by tap and a caption selector.

## Creation, publishing and appearance updates

- Generated images use a sanitized, readable filename based on the user's original prompt, with a unique ID suffix. Original prompt metadata remains unchanged.
- Generated captions and images can be created in either order. A caption editor can generate, import or edit text and hashtags, preview the result, and save it to a selected asset. A previously generated caption can also be paired in the asset lobby. Pairings are workspace-scoped asset metadata.
- Caption imports accept UTF-8 TXT/Markdown or text PDFs up to 2 MB, with a 20-page PDF limit and 30,000 extracted-character cap. Scanned PDFs are explained as needing OCR; no OCR or file execution is performed. Import is previewed before use. Uploading caption source files never creates media assets.
- Media uploads appear in Publish, where generated assets and uploads can be combined in a batch of up to four. The review dialog states that each asset is a separate post to each selected channel, with the reviewed caption. Now and future schedules share the same account, caption, asset and confirmation requirements.
- Social providers fetch assets themselves, so dispatch creates a signed HTTPS media link expiring in one hour. Local/private object storage uses `AEVRA_PUBLIC_API_BASE_URL` (public HTTPS API origin, no trailing slash); publicly reachable HTTPS object storage can use its native presigned URL. Scheduled jobs retain only the workspace asset download path and mint a new time-limited link when the worker dispatches.
- The scheduled-post worker atomically claims due items. Explicit retries reuse a resettable idempotent job, so a failed provider call can be attempted again without duplicating a completed post. Calendar cells use device-local scheduling time consistently with the schedule field and require confirmation.
- The sign-in landing page adds a restrained animated product tour, reduced-motion support and an icon theme toggle. Creator work areas keep light/dark icons; password visibility changes immediately. Admin styling retains its separate sign-in and operational data boundaries.

## Expanded audit: this turn

| Area | Finding / control | Remaining limitation |
|---|---|---|
| Asset delivery | Signed links are bound to workspace and asset, use constant-time HMAC verification, HTTPS, one-hour expiry and `private, no-store`; no OAuth token or filename enters the signature. | Local/private storage requires the API's public HTTPS origin in deployment. Confirm public reachability and production CDN/provider requirements for Instagram/Facebook before rollout. |
| Caption file handling | Authenticated workspace editor check precedes 2 MB bounded reads. PDF page and output size are bounded; malformed/encrypted/empty documents fail closed; UTF-8 and extensions are checked. | Scanned PDF text requires a separate OCR capability. |
| Publishing | Tests cover publish now, deferred schedule, worker dispatch, retry, stable idempotency and per-asset provider delivery. Worker compare-and-set prevents duplicate concurrent claims. | Provider credentials, public external networks, platform approval and actual publishing cannot be proven by local mocked-provider tests. |
| Batch semantics | Maximum of four assets; caption applies consistently and each asset/channel pair gets a separate status and stable idempotency key. | Different per-channel or per-asset copy still requires separate submissions. |
| Accessibility and layout | Browser checked map keyboard/table selection, theme and schedule review. Flutter widgets check the advanced calendar at 320 px; browser publishing calendar checked at 390 px. Reduced-motion preference suppresses decorative landing animation. | This is automated/local browser coverage, not a full assistive-technology or physical-device audit. |
| UI scope | Removed “API connected” status copy and asset upload from Create. Landing page includes a mode toggle; admin remains on the separate portal and data views. | Existing active admin/customer authorization policies and production accounts still need deployment-level review. |

This is an implementation self-audit, not an independent security certification or live-provider delivery test.

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

- API regression suite: **95 tests passed**, including the existing ML/advanced tests and six new caption, delivery, and scheduler tests.
- ML-specific tests cover all ten feature paths, empty/punctuation-only/unseen vocabularies, deterministic text results, unsupported platforms, baseline rejection, delayed-label purging, out-of-range drafts, outliers, recursive forecasts, missing days, counter resets, auth, tenant boundaries, input limits, stored hashtag metadata and inference contention.
- Web Biome formatting, TypeScript and optimized Next.js production build pass.
- Browser: real ML engine with synthetic local fixture; ten rendered results, stale-input notice, and 390px responsive layout checked. No live tenant writes or provider calls.
- Flutter: **analysis clean; 12 tests passed**. Added 320px widget coverage for all three advanced labs, missing-data calendar, stale results, caption pairing and publish input.
- Synthetic local benchmark: 120 posts, 10 text examples and 35 daily snapshots; all ten base feature paths returned results in **0.415 seconds** after import. Not a cold-start, maximum-load, remote-host or production benchmark.
- Synthetic prediction validation: 89 training samples, 7 purged samples and 24 holdout samples; MAE **0.0393** versus median baseline **0.758** engagements per 100 impressions.
- Synthetic recursive forecast: seven-day MAE **5.733** versus weekly baseline **14.0** engagements. One fixed synthetic post cohort.

## Deployment and operating limits

Install the updated API dependencies and deploy API, web and mobile changes together. No schema migration is required. Tested locally with scikit-learn 1.9.1, NumPy 2.5.3 and SciPy 1.18.1. No model download, external ML account or new secret is required.

For real-world validation, collect enough dated metrics through existing analytics ingestion, then evaluate on representative tenant history. Retain the withholding gates. Monitor inference latency, 429s, data freshness and holdout performance before considering automated workflows. Current implementation deliberately contains no auto-publishing integration.

Text models measure lexical similarity, not semantic understanding, factual correctness, sentiment, image pixels or live trends. Brand affinity is a vocabulary match, not a compliance check. Platform/time rankings are observational, not evidence that changing a platform or time causes improved engagement.

Implementation entry points: `apps/api/aevra_api/services/ml_insights.py`, `apps/api/aevra_api/api/routes/ml.py`, `apps/web/components/ml-studio.tsx`, `apps/mobile/lib/screens/ml_insights_screen.dart`.

Algorithm reference: [scikit-learn TF-IDF documentation](https://scikit-learn.org/stable/modules/generated/sklearn.feature_extraction.text.TfidfVectorizer.html).
