"use client";

import { Button } from "@/components/ui/button";
import type { AdminOverview } from "@/lib/api";

export type AdminSection = "overview" | "media" | "publishing" | "analytics";
const number = (value: number) => new Intl.NumberFormat().format(value);

export function AdminDashboard({
  data,
  section,
  onRefresh,
}: {
  data: AdminOverview | null;
  section: AdminSection;
  onRefresh: () => void;
}) {
  if (!data)
    return (
      <section className="live-panel">
        <h1>Customer operations</h1>
        <p>Usage data is not available yet.</p>
        <Button size="sm" onClick={onRefresh}>
          Refresh report
        </Button>
      </section>
    );
  const totals = data.totals;
  const headings = {
    overview: [
      "Customer overview",
      "Adoption, workspace usage, and social performance across customers.",
    ],
    media: ["AI & media usage", "Recorded generation activity by provider and model."],
    publishing: [
      "Publishing operations",
      "Channel health, upcoming workload, and publishing outcomes.",
    ],
    analytics: [
      "Customer analytics",
      "Platform performance from the latest collected sample for each post.",
    ],
  };
  const cards =
    section === "media"
      ? [
          ["Generation runs", totals.generation_runs],
          ["Generated assets", totals.generated_assets],
          ["Input tokens recorded", totals.prompt_tokens],
          ["Output tokens recorded", totals.completion_tokens],
        ]
      : section === "publishing"
        ? [
            ["Channels", totals.channels],
            ["Upcoming schedules", totals.scheduled],
            ["Published posts", totals.published],
            ["Failed publish jobs", totals.failed],
          ]
        : section === "analytics"
          ? [
              ["Measured posts", totals.measured_posts],
              ["Impressions", totals.impressions],
              ["Engagements", totals.engagements],
              ["Clicks", totals.clicks],
            ]
          : [
              ["Customers", data.users_total],
              ["Approved", data.users_approved],
              ["Generated assets", totals.generated_assets],
              ["Published posts", totals.published],
            ];
  return (
    <div className="admin-dashboard">
      <header className="admin-heading">
        <p className="live-kicker">VAE administration</p>
        <h1>{headings[section][0]}</h1>
        <p>{headings[section][1]}</p>
        <small>
          Updated {new Date(data.generated_at).toLocaleString()} · Operational KPIs only
        </small>
        <Button size="sm" variant="secondary" onClick={onRefresh}>
          Refresh report
        </Button>
      </header>
      <div className="admin-stat-grid">
        {cards.map(([label, value]) => (
          <article className="live-panel" key={label}>
            <span>{label}</span>
            <strong>{number(Number(value))}</strong>
          </article>
        ))}
      </div>
      {section === "media" && (
        <section className="live-panel">
          <h2>Provider & model activity</h2>
          <p>
            LLM counts represent recorded campaign runs. Media counts represent generated assets,
            not provider requests. Token totals cover runs with recorded usage; billing and
            untracked calls are excluded.
          </p>
          <div className="admin-table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Provider / model</th>
                  <th>Activity</th>
                  <th>Count</th>
                  <th>Failed</th>
                  <th>Recorded tokens</th>
                  <th>Metered runs</th>
                </tr>
              </thead>
              <tbody>
                {data.models.map((item) => (
                  <tr key={`${item.kind}-${item.provider}-${item.model}`}>
                    <th>
                      {item.provider}
                      <small>{item.model}</small>
                    </th>
                    <td>{item.kind === "llm" ? "LLM runs" : "Media assets"}</td>
                    <td>{number(item.requests)}</td>
                    <td>{number(item.failed)}</td>
                    <td>
                      {item.kind === "llm"
                        ? number(item.prompt_tokens + item.completion_tokens)
                        : "Not metered"}
                    </td>
                    <td>{item.kind === "llm" ? `${item.metered_runs} / ${item.requests}` : "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {!data.models.length && <p>No recorded generation activity yet.</p>}
        </section>
      )}
      {section !== "media" && (
        <section className="live-panel">
          <h2>
            {section === "publishing" ? "Channels & schedules" : "Social platform performance"}
          </h2>
          <p>
            {data.metrics_updated_at
              ? `Latest metric collection: ${new Date(data.metrics_updated_at).toLocaleString()}.`
              : "No social performance samples collected yet."}{" "}
            Impressions are platform-reported views, not website visits.
          </p>
          <div className="admin-table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Platform</th>
                  <th>Connected / total</th>
                  <th>Scheduled</th>
                  <th>Queued</th>
                  <th>Published</th>
                  {section === "publishing" ? (
                    <>
                      <th>Publish failures</th>
                      <th>Schedule failures</th>
                    </>
                  ) : (
                    <>
                      <th>Impressions</th>
                      <th>Engagements</th>
                      <th>Clicks</th>
                    </>
                  )}
                </tr>
              </thead>
              <tbody>
                {data.platforms.map((item) => (
                  <tr key={item.platform}>
                    <th className="admin-platform">{item.platform}</th>
                    <td>
                      {item.connected} / {item.channels}
                    </td>
                    <td>{number(item.scheduled)}</td>
                    <td>{number(item.queued)}</td>
                    <td>{number(item.published)}</td>
                    {section === "publishing" ? (
                      <>
                        <td>{number(item.failed)}</td>
                        <td>{number(item.schedule_failed)}</td>
                      </>
                    ) : (
                      <>
                        <td>{number(item.impressions)}</td>
                        <td>{number(item.engagements)}</td>
                        <td>{number(item.clicks)}</td>
                      </>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {!data.platforms.length && <p>No connected channels or platform activity yet.</p>}
        </section>
      )}
      <section className="live-panel">
        <h2>{section === "media" ? "Customer generation usage" : "Customer usage"}</h2>
        <p>
          Workspace totals across each customer’s memberships. Shared workspaces appear for each
          member; headline totals count each workspace once.
        </p>
        <div className="admin-table-wrap">
          <table>
            <thead>
              <tr>
                <th>Customer</th>
                <th>Status</th>
                {section === "media" ? (
                  <>
                    <th>LLM runs</th>
                    <th>Generated assets</th>
                    <th>Recorded tokens</th>
                  </>
                ) : (
                  <>
                    <th>Assets</th>
                    <th>Channels</th>
                    <th>Scheduled</th>
                    <th>Published</th>
                    <th>Engagements</th>
                  </>
                )}
              </tr>
            </thead>
            <tbody>
              {data.users.map((item) => (
                <tr key={item.user_id}>
                  <th>
                    {item.display_name}
                    <small>{item.brand_name || item.account_type}</small>
                    {section !== "media" && !!item.platforms?.length && (
                      <details className="admin-customer-platforms">
                        <summary>Platform KPIs</summary>
                        {item.platforms.map((platform) => (
                          <p key={platform.platform}>
                            <b>{platform.platform}</b>
                            <br />
                            {platform.channels} channels · {platform.scheduled} scheduled ·{" "}
                            {platform.published} published
                            <br />
                            {number(platform.impressions)} impressions ·{" "}
                            {number(platform.engagements)} engagements
                          </p>
                        ))}
                      </details>
                    )}
                  </th>
                  <td>{item.account_status.replaceAll("_", " ")}</td>
                  {section === "media" ? (
                    <>
                      <td>{number(item.generation_runs)}</td>
                      <td>{number(item.generated_assets)}</td>
                      <td>{number(item.prompt_tokens + item.completion_tokens)}</td>
                    </>
                  ) : (
                    <>
                      <td>{number(item.assets)}</td>
                      <td>{number(item.channels)}</td>
                      <td>{number(item.scheduled)}</td>
                      <td>{number(item.published)}</td>
                      <td>{number(item.engagements)}</td>
                    </>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!data.users.length && <p>No customer activity yet.</p>}
      </section>
    </div>
  );
}
