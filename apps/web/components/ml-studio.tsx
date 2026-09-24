"use client";

import { useRef, useState } from "react";
import { AdvancedAnalytics } from "@/components/advanced-analytics";
import { Button } from "@/components/ui/button";
import { api, type MlReport, type Platform } from "@/lib/api";

const ideas = [
  "Duplicate-copy detection",
  "Brand-language match",
  "Topic discovery",
  "Media matching",
  "Hashtag suggestions",
  "Engagement prediction",
  "Posting-time suggestions",
  "Channel recommendations",
  "Performance anomalies",
  "Seven-day engagement forecast",
];

export function MlStudio({
  token,
  workspaceId,
  initialDraft = "",
}: {
  token: string;
  workspaceId: string;
  initialDraft?: string;
}) {
  const [advanced, setAdvanced] = useState(false);
  const [draft, setDraft] = useState(initialDraft);
  const [platform, setPlatform] = useState<Platform>("instagram");
  const [report, setReport] = useState<MlReport | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const generation = useRef(0);
  const [analyzedInput, setAnalyzedInput] = useState("");
  const stale = !!report && analyzedInput !== JSON.stringify([draft, platform]);
  async function analyze() {
    const id = ++generation.current;
    setBusy(true);
    setError(null);
    const input = JSON.stringify([draft, platform]);
    try {
      const next = await api.mlInsights(token, workspaceId, draft, platform);
      if (id === generation.current) {
        setReport(next);
        setAnalyzedInput(input);
      }
    } catch (reason) {
      if (id === generation.current)
        setError(reason instanceof Error ? reason.message : "Analysis failed. Try again.");
    } finally {
      if (id === generation.current) setBusy(false);
    }
  }
  return (
    <div className="ml-studio">
      <header className="admin-heading">
        <p className="live-kicker">Learn from your work</p>
        <h1>ML insights</h1>
        <p>
          Workspace-local machine learning and visual analytics. Every suggestion stays yours to
          review.
        </p>
      </header>
      <fieldset className="live-tabs" aria-label="Analysis mode">
        <button
          type="button"
          className={!advanced ? "active" : ""}
          aria-pressed={!advanced}
          onClick={() => setAdvanced(false)}
        >
          10 ML tools
        </button>
        <button
          type="button"
          className={advanced ? "active" : ""}
          aria-pressed={advanced}
          onClick={() => setAdvanced(true)}
        >
          3 advanced labs
        </button>
      </fieldset>
      {advanced ? (
        <AdvancedAnalytics
          key={workspaceId}
          token={token}
          workspaceId={workspaceId}
          initialDraft={draft}
        />
      ) : (
        <>
          <form
            className="live-panel ml-input"
            onSubmit={(event) => {
              event.preventDefault();
              void analyze();
            }}
          >
            <label className="live-field">
              <span>Draft caption or creative brief</span>
              <textarea
                rows={4}
                maxLength={6000}
                value={draft}
                onChange={(event) => setDraft(event.target.value)}
                placeholder="Paste a draft to find matching media, similar copy, and relevant hashtags…"
              />
            </label>
            <label className="live-field">
              <span>Target platform</span>
              <select
                value={platform}
                onChange={(event) => setPlatform(event.target.value as Platform)}
              >
                {["instagram", "facebook", "linkedin", "threads", "x", "youtube"].map((name) => (
                  <option key={name} value={name}>
                    {name}
                  </option>
                ))}
              </select>
            </label>
            <p>
              Runs locally on the server. Your draft is not saved. Leave it empty to explore topics,
              anomalies, and forecasting.
            </p>
            <Button type="submit" disabled={busy}>
              {busy ? "Learning from your workspace…" : "Analyze workspace"}
            </Button>
            {error && (
              <p role="alert" className="live-alert error">
                {error}
              </p>
            )}
            {stale && (
              <p role="status">
                Your draft or platform changed. Analyze again to refresh these results.
              </p>
            )}
          </form>
          {!report && (
            <section className="live-panel">
              <h2>What you can discover</h2>
              <ol className="ml-feature-list">
                {ideas.map((idea) => (
                  <li key={idea}>{idea}</li>
                ))}
              </ol>
              <p>
                Some tools need saved captions or media. Predictions need enough comparable
                performance history; unavailable results are clearly marked.
              </p>
            </section>
          )}
          {report && (
            <>
              <div className="ml-results" aria-live="polite">
                {report.features.map((feature) => (
                  <section className="live-panel ml-result" key={feature.id}>
                    <div className="ml-result-title">
                      <h2>{feature.title}</h2>
                      <span className="live-status">
                        {feature.status === "ready"
                          ? "Analysis ready"
                          : feature.status === "unreliable"
                            ? "Prediction withheld"
                            : "Needs data"}
                      </span>
                    </div>
                    <p>{feature.explanation}</p>
                    <small>
                      {feature.sample_count} samples · Minimum {feature.minimum_samples}
                    </small>
                    {feature.items.length > 0 ? (
                      <ul>
                        {feature.items.map((item) => (
                          <li key={item.reference_id ?? item.label}>
                            <strong>{item.label}</strong>
                            <span>
                              {item.detail}
                              {item.score !== null
                                ? ` · ${item.score.toLocaleString(undefined, { maximumFractionDigits: 3 })}`
                                : ""}
                            </span>
                          </li>
                        ))}
                      </ul>
                    ) : (
                      feature.status === "ready" && (
                        <p>No matching suggestions or unusual patterns in this sample.</p>
                      )
                    )}
                    <details>
                      <summary>Method & validation</summary>
                      <p>{feature.method}</p>
                      {Object.entries(feature.diagnostics).map(([key, value]) => (
                        <p key={key}>
                          {key.replaceAll("_", " ")}: {value}
                        </p>
                      ))}
                    </details>
                  </section>
                ))}
              </div>
              <section className="live-panel">
                <h2>Analysis audit</h2>
                <p>
                  {report.model_version} · {new Date(report.generated_at).toLocaleString()} ·{" "}
                  {report.timezone}
                </p>
                <p>
                  {report.audit.training_scope}. {report.audit.external_requests} external AI
                  requests. No automatic publishing or scheduling.
                </p>
                {report.audit.history_capped && (
                  <p>History was capped for performance; results describe the sampled history.</p>
                )}
                <ul>
                  {report.audit.notes.map((note) => (
                    <li key={note}>{note}</li>
                  ))}
                </ul>
              </section>
            </>
          )}
        </>
      )}
    </div>
  );
}
