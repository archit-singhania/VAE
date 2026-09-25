"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { type AdvancedReport, api, type Platform } from "@/lib/api";

const colors = ["#9a5a2e", "#327d70", "#567dad", "#8a61a8", "#ad654d"];
const n = (value: number | null) =>
  value === null ? "—" : value.toLocaleString(undefined, { maximumFractionDigits: 3 });

export function AdvancedAnalytics({
  token,
  workspaceId,
  initialDraft,
}: {
  token: string;
  workspaceId: string;
  initialDraft: string;
}) {
  const [a, setA] = useState(initialDraft);
  const [b, setB] = useState("");
  const [platform, setPlatform] = useState<Platform>("instagram");
  const [report, setReport] = useState<AdvancedReport | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [input, setInput] = useState("");
  const [selected, setSelected] = useState<string | null>(null);
  const [filter, setFilter] = useState("all");
  const [page, setPage] = useState(0);
  async function run() {
    if (busy) return;
    setBusy(true);
    setError("");
    const snapshot = JSON.stringify([a, b, platform]);
    try {
      const next = await api.advancedInsights(token, workspaceId, a, b, platform);
      setReport(next);
      setInput(snapshot);
      setSelected(null);
      setFilter("all");
      setPage(0);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Analysis failed.");
    } finally {
      setBusy(false);
    }
  }
  const points =
    report?.content_map.points.filter((point) => filter === "all" || point.platform === filter) ??
    [];
  const active = points.find((point) => point.id === selected);
  const c = report?.comparison;
  const q = report?.data_quality;
  const d = q?.drift;
  return (
    <div className="advanced-labs">
      <section className="live-panel">
        <h2>Advanced analytics lab</h2>
        <p>
          Explore content, compare two drafts, and check whether your data supports trustworthy
          insights. Leave drafts blank to run the map and data checks only.
        </p>
        <form
          onSubmit={(event) => {
            event.preventDefault();
            void run();
          }}
          className="advanced-inputs"
        >
          <label className="live-field">
            <span>Draft A</span>
            <textarea
              maxLength={6000}
              rows={3}
              value={a}
              onChange={(event) => setA(event.target.value)}
            />
          </label>
          <label className="live-field">
            <span>Draft B</span>
            <textarea
              maxLength={6000}
              rows={3}
              value={b}
              onChange={(event) => setB(event.target.value)}
            />
          </label>
          <label className="live-field">
            <span>Comparison & drift platform</span>
            <select
              value={platform}
              onChange={(event) => setPlatform(event.target.value as Platform)}
            >
              {["instagram", "facebook", "linkedin", "threads", "x", "youtube"].map((value) => (
                <option key={value}>{value}</option>
              ))}
            </select>
          </label>
          <Button type="submit" disabled={busy}>
            {busy ? "Analyzing…" : "Run advanced analysis"}
          </Button>
        </form>
        {error && <p role="alert">{error}</p>}
        {report && input !== JSON.stringify([a, b, platform]) && (
          <p role="status">Inputs changed. Run again to refresh these results.</p>
        )}
      </section>
      {!report && (
        <div className="advanced-preview">
          <article className="live-panel">
            <h3>Content-performance map</h3>
            <p>An interactive map of related wording with measured engagement overlays.</p>
          </article>
          <article className="live-panel">
            <h3>Draft comparison lab</h3>
            <p>Compare two drafts with week-block resampling and validation checks.</p>
          </article>
          <article className="live-panel">
            <h3>Data health & distribution shifts</h3>
            <p>See coverage, collection gaps, freshness and changes in platform outcomes.</p>
          </article>
        </div>
      )}
      {report && (
        <>
          <section className="live-panel">
            <h2>Content-performance map</h2>
            <p>{report.content_map.explanation}</p>
            {report.content_map.status === "ready" ? (
              <>
                <label className="live-field">
                  <span>Filter map by platform</span>
                  <select
                    value={filter}
                    onChange={(event) => {
                      setFilter(event.target.value);
                      setPage(0);
                      setSelected(null);
                    }}
                  >
                    <option value="all">All platforms</option>
                    {Array.from(new Set(report.content_map.points.map((point) => point.platform)))
                      .sort()
                      .map((value) => (
                        <option key={value}>{value}</option>
                      ))}
                  </select>
                </label>
                <p>
                  {points.length} visible texts · Two axes retain{" "}
                  {n((report.content_map.explained_variance ?? 0) * 100)}% of feature variance
                  {report.content_map.capped ? " · Map capped at 500 texts" : ""}.
                </p>
                {/* biome-ignore lint/a11y/useSemanticElements: SVG needs group semantics; an HTML fieldset cannot replace it. */}
                <svg
                  className="content-scatter"
                  viewBox="0 0 800 420"
                  role="group"
                  aria-label="Interactive content map. Select a point or use the table below."
                >
                  <title>Content-performance map</title>
                  <rect x="25" y="25" width="750" height="370" rx="14" fill="var(--vae-input)" />
                  {points.map((point) => (
                    // biome-ignore lint/a11y/useSemanticElements: SVG points use keyboard-enabled button roles; native buttons are provided in the table.
                    <g
                      key={point.id}
                      role="button"
                      tabIndex={0}
                      aria-label={`${point.caption}, ${point.platform}, ${point.engagement_rate === null ? "no measured rate" : `rate ${point.engagement_rate}`}`}
                      onClick={() => setSelected(point.id)}
                      onKeyDown={(event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          setSelected(point.id);
                        }
                      }}
                    >
                      <title>{point.caption}</title>
                      <circle
                        cx={40 + point.x * 720}
                        cy={380 - point.y * 340}
                        r={point.id === selected ? 10 : 7}
                        fill={
                          point.engagement_rate === null
                            ? "var(--vae-input)"
                            : colors[point.cluster % colors.length]
                        }
                        stroke={colors[point.cluster % colors.length]}
                        strokeWidth={point.id === selected ? 4 : 2}
                      />
                    </g>
                  ))}
                </svg>
                <p>
                  Filled points have measured rates; hollow points have none. Select a point for its
                  caption and rate. Theme colors are also identified by number in the table.
                </p>
                <div className="map-legend">
                  {report.content_map.clusters.map((cluster) => (
                    <span key={cluster.id}>
                      <i style={{ background: colors[cluster.id % colors.length] }} />
                      Theme {cluster.id + 1}: {cluster.label}
                    </span>
                  ))}
                </div>
                <div className="map-selection" aria-live="polite">
                  {active ? (
                    <>
                      <strong>{active.caption}</strong>
                      <p>
                        {active.platform} · Theme {active.cluster + 1} ·{" "}
                        {active.engagement_rate === null
                          ? "No matched seven-day rate"
                          : `${n(active.engagement_rate)} engagements per 100 impressions`}
                      </p>
                    </>
                  ) : (
                    <p>Select a point or table row to inspect it.</p>
                  )}
                </div>
                <div className="admin-table-wrap">
                  <table className="advanced-table">
                    <caption>Accessible content map data</caption>
                    <thead>
                      <tr>
                        <th>Caption</th>
                        <th>Platform</th>
                        <th>Theme</th>
                        <th>Measured rate</th>
                      </tr>
                    </thead>
                    <tbody>
                      {points.slice(page * 20, page * 20 + 20).map((point) => (
                        <tr key={point.id}>
                          <td>
                            <button type="button" onClick={() => setSelected(point.id)}>
                              {point.caption}
                            </button>
                          </td>
                          <td>{point.platform}</td>
                          <td>{point.cluster + 1}</td>
                          <td>{n(point.engagement_rate)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <div className="advanced-pagination">
                  <Button
                    size="sm"
                    variant="secondary"
                    disabled={!page}
                    onClick={() => setPage(page - 1)}
                  >
                    Previous
                  </Button>
                  <span>
                    Page {page + 1} of {Math.max(1, Math.ceil(points.length / 20))}
                  </span>
                  <Button
                    size="sm"
                    variant="secondary"
                    disabled={(page + 1) * 20 >= points.length}
                    onClick={() => setPage(page + 1)}
                  >
                    Next
                  </Button>
                </div>
              </>
            ) : (
              <p role="status">Map needs more varied saved copy.</p>
            )}
          </section>
          {c && (
            <section className="live-panel">
              <h2>Draft comparison lab</h2>
              <p>{c.explanation}</p>
              {c.status === "ready" ? (
                <>
                  <div className="advanced-preview">
                    <article>
                      <small>Draft A estimated rate</small>
                      <strong>{n(c.prediction_a)}</strong>
                    </article>
                    <article>
                      <small>Draft B estimated rate</small>
                      <strong>{n(c.prediction_b)}</strong>
                    </article>
                    <article>
                      <small>B minus A</small>
                      <strong>{n(c.delta)}</strong>
                    </article>
                  </div>
                  <p>
                    Week-block resampling range:{" "}
                    <strong>
                      {n(c.delta_range?.[0] ?? null)} to {n(c.delta_range?.[1] ?? null)}
                    </strong>{" "}
                    · {c.bootstrap_samples} fitted resamples across {c.week_blocks} weeks.
                  </p>
                  <p>
                    {c.delta_range && c.delta_range[0] <= 0 && c.delta_range[1] >= 0
                      ? "The range includes zero: no stable model preference between these drafts."
                      : "The model preference persists in the central resampling range; test it before changing your strategy."}
                  </p>
                </>
              ) : (
                <p role="status">
                  {c.status === "unreliable"
                    ? "Comparison withheld by validation checks."
                    : "Comparison needs more input or history."}
                </p>
              )}
              <details>
                <summary>Validation diagnostics</summary>
                {Object.entries(c.diagnostics).map(([key, value]) => (
                  <p key={key}>
                    {key.replaceAll("_", " ")}: {value}
                  </p>
                ))}
              </details>
            </section>
          )}
          {q && d && (
            <section className="live-panel">
              <h2>Data health & distribution shifts</h2>
              <p>{q.explanation}</p>
              <div className="advanced-preview">
                <article>
                  <small>Seven-day label coverage</small>
                  <strong>{q.coverage_percent === null ? "—" : `${q.coverage_percent}%`}</strong>
                  <span>
                    {n(q.matched_posts)} / {n(q.mature_posts)} mature posts
                  </span>
                </article>
                <article>
                  <small>Days with observations</small>
                  <strong>{q.observed_days} / 35</strong>
                  <span>{q.missing_days} days without observations</span>
                </article>
                <article>
                  <small>Latest collection age</small>
                  <strong>{q.freshness_hours === null ? "—" : `${n(q.freshness_hours)}h`}</strong>
                  <span>
                    {q.latest_metric_at
                      ? new Date(q.latest_metric_at).toLocaleString()
                      : "No collection recorded"}
                  </span>
                </article>
              </div>
              <h3>35-day observation calendar · UTC</h3>
              <ul className="quality-calendar" aria-label="Daily metric observations">
                {q.timeline.map((day) => (
                  <li
                    className={day.observed_posts ? "observed" : "missing"}
                    key={day.date}
                    title={`${day.date}: ${day.observed_posts} observed posts`}
                  >
                    <time dateTime={day.date}>{day.date.slice(5)}</time>
                    <strong>{day.observed_posts}</strong>
                    <small>{day.observed_posts ? "posts" : "no data"}</small>
                  </li>
                ))}
              </ul>
              <h3>Distribution check · {report.platform}</h3>
              <p>{d.explanation}</p>
              <p>
                Previous: {d.previous_samples} posts · Recent: {d.recent_samples} posts. Windows:{" "}
                {d.previous_start.slice(0, 10)} → {d.recent_start.slice(0, 10)} →{" "}
                {d.window_end.slice(0, 10)} (UTC).
              </p>
              {d.status !== "needs_data" ? (
                <>
                  <p>
                    <strong>
                      {d.status === "difference_detected"
                        ? "Distribution difference detected — investigate"
                        : "No clear distribution difference detected"}
                    </strong>
                  </p>
                  <p>
                    Median rate: {n(d.previous_median)} → {n(d.recent_median)} · KS distance:{" "}
                    {n(d.ks_distance)} · Permutation p-value: {n(d.permutation_p)}
                  </p>
                </>
              ) : (
                <p>Not enough comparable posts in both windows.</p>
              )}
              {q.history_capped && (
                <p>History is capped. Coverage and gaps describe the sampled dataset.</p>
              )}
            </section>
          )}
          <p className="live-helper">
            {report.version} · {new Date(report.generated_at).toLocaleString()} ·{" "}
            {report.audit.scope}. No external AI requests or automatic actions.
          </p>
        </>
      )}
    </div>
  );
}
