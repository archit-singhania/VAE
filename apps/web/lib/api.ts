export type Platform = "linkedin" | "instagram" | "threads" | "x" | "facebook" | "youtube";

export type User = {
  id: string;
  email: string;
  display_name: string;
  is_active: boolean;
  is_admin: boolean;
  account_status: string;
  account_type: "creator" | "business";
  brand_name: string | null;
  avatar_url: string | null;
  created_at: string;
};

export type PaymentSubmission = {
  id: string;
  user_id: string;
  tenant_id: string;
  email: string;
  display_name: string;
  amount: string;
  currency: string;
  utr_reference: string | null;
  proof_asset_id: string | null;
  status: string;
  admin_note: string | null;
  submitted_at: string | null;
};

export type AdminUsage = {
  assets: number;
  generated_assets: number;
  channels: number;
  scheduled: number;
  queued: number;
  published: number;
  failed: number;
  schedule_failed: number;
  impressions: number;
  engagements: number;
  clicks: number;
  measured_posts: number;
  generation_runs: number;
  prompt_tokens: number;
  completion_tokens: number;
};
export type AdminOverview = {
  users_total: number;
  users_approved: number;
  assets_total: number;
  channels_total: number;
  totals: AdminUsage;
  users: Array<
    AdminUsage & {
      platforms: Array<{
        platform: string;
        channels: number;
        scheduled: number;
        published: number;
        impressions: number;
        engagements: number;
      }>;
      user_id: string;
      display_name: string;
      brand_name: string | null;
      account_type: string;
      account_status: string;
      created_at: string;
    }
  >;
  platforms: Array<AdminUsage & { platform: string; connected: number }>;
  models: Array<{
    kind: string;
    provider: string;
    model: string;
    requests: number;
    failed: number;
    prompt_tokens: number;
    completion_tokens: number;
    metered_runs: number;
  }>;
  metrics_updated_at: string | null;
  generated_at: string;
};

export type MlReport = {
  model_version: string;
  generated_at: string;
  timezone: string;
  features: Array<{
    id: string;
    title: string;
    method: string;
    status: "ready" | "needs_data" | "unreliable";
    sample_count: number;
    minimum_samples: number;
    explanation: string;
    items: Array<{
      label: string;
      detail: string;
      score: number | null;
      reference_id: string | null;
    }>;
    diagnostics: Record<string, string | number>;
  }>;
  audit: {
    training_scope: string;
    external_requests: number;
    automatic_actions: boolean;
    models_persisted: boolean;
    history_capped: boolean;
    limits: Record<string, number>;
    notes: string[];
  };
};

export type AdvancedReport = {
  version: string;
  generated_at: string;
  platform: string;
  timezone: string;
  content_map: {
    status: string;
    explanation: string;
    sample_count: number;
    capped: boolean;
    explained_variance: number | null;
    clusters: Array<{ id: number; label: string; count: number }>;
    points: Array<{
      id: string;
      caption: string;
      platform: string;
      cluster: number;
      x: number;
      y: number;
      engagement_rate: number | null;
    }>;
  };
  comparison: {
    status: string;
    explanation: string;
    prediction_a: number | null;
    prediction_b: number | null;
    delta: number | null;
    delta_range: [number, number] | null;
    bootstrap_samples: number;
    week_blocks: number;
    diagnostics: Record<string, string | number>;
  };
  data_quality: {
    coverage_percent: number | null;
    mature_posts: number | null;
    matched_posts: number | null;
    metric_samples: number | null;
    latest_metric_at: string | null;
    freshness_hours: number | null;
    observed_days: number;
    missing_days: number;
    history_capped: boolean;
    explanation: string;
    timeline: Array<{ date: string; observed_posts: number }>;
    drift: {
      status: string;
      explanation: string;
      previous_samples: number;
      recent_samples: number;
      previous_start: string;
      recent_start: string;
      window_end: string;
      ks_distance: number | null;
      permutation_p: number | null;
      previous_median: number | null;
      recent_median: number | null;
    };
  };
  audit: {
    scope: string;
    external_requests: number;
    automatic_actions: boolean;
    drafts_saved: boolean;
    history_capped: boolean;
  };
};

export type Workspace = {
  id: string;
  organization_id: string;
  name: string;
  slug: string;
  timezone: string;
  is_active: boolean;
  created_at: string;
};

export type Brand = {
  id: string;
  workspace_id: string;
  name: string;
  slug: string;
  description: string;
  website_url: string | null;
  industry: string | null;
  tone_attributes: string[];
  target_audiences: string[];
  preferred_ctas: string[];
  preferred_hashtags: string[];
  status: "draft" | "active" | "archived";
  created_at: string;
  updated_at: string;
};

export type Campaign = {
  id: string;
  workspace_id: string;
  brand_id: string;
  name: string;
  goal: string;
  product_service: string;
  audience: string;
  instructions: string;
  platforms: Platform[];
  media_types: string[];
  publishing_mode: "manual" | "assisted" | "autonomous";
  status: string;
  current_revision: number;
  latest_feedback: string | null;
  error_message: string | null;
  created_at: string;
  updated_at: string;
};

export type ContentVariant = {
  id: string;
  campaign_id: string;
  revision: number;
  platform: Platform;
  title: string | null;
  caption: string;
  hashtags: string[];
  call_to_action: string | null;
  status: "draft" | "approved" | "rejected" | "superseded";
  quality_score: number;
  validation_issues: string[];
  citations: Array<{ document_title?: string; excerpt?: string; [key: string]: unknown }>;
  generated_by_model: string;
  created_at: string;
};

export type KnowledgeDocument = {
  id: string;
  title: string;
  source_type: string;
  source_uri: string | null;
  content_length: number;
  status: string;
  created_at: string;
};

export type Citation = {
  chunk_id: string;
  document_id: string;
  document_title: string;
  source_uri: string | null;
  score: number;
  excerpt: string;
};

export type MediaAsset = {
  asset_metadata?: { caption?: string };
  id: string;
  campaign_id: string | null;
  media_type: "image" | "video";
  status: string;
  filename: string;
  mime_type: string;
  width: number | null;
  height: number | null;
  prompt: string | null;
  created_at: string;
  download_url: string | null;
};

export type SocialAccount = {
  id: string;
  platform: Platform;
  external_account_id: string;
  display_name: string;
  status: "connected" | "paused" | "revoked";
  capabilities: string[];
  granted_scopes?: string[];
  access_token_expires_at?: string | null;
  last_verified_at: string | null;
};

export type ScheduledPost = {
  id: string;
  campaign_id: string;
  social_account_id: string;
  scheduled_for: string;
  status: string;
  payload: { text?: string; media_urls?: string[] };
  created_at: string;
};

export type PublishJob = {
  id: string;
  status: string;
  external_url: string | null;
  error_message: string | null;
  published_at: string | null;
};

export type PostMetric = {
  id: string;
  social_account_id: string;
  external_post_id: string;
  collected_at: string;
  impressions: number;
  engagements: number;
  clicks: number;
  likes: number;
  comments: number;
  shares: number;
  metric_metadata: Record<string, unknown>;
};

export type CampaignGeneration = {
  campaign: Campaign;
  variants: ContentVariant[];
  plan: Record<string, unknown>;
  steps: Array<{ node_name: string; status: string; duration_ms: number }>;
};

export class ApiError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "/api/v1";

function apiUrl(path: string) {
  return `${API_BASE_URL}${path.startsWith("/") ? path : `/${path}`}`;
}

export async function request<T>(
  path: string,
  token?: string | null,
  init: RequestInit = {},
): Promise<T> {
  const headers = new Headers(init.headers);
  // Browser sessions use an HTTP-only cookie. Native clients can keep passing
  // a bearer token; the sentinel is deliberately never serialized as a header.
  if (token && token !== "cookie") headers.set("Authorization", `Bearer ${token}`);
  if (init.body && !(init.body instanceof FormData) && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  const response = await fetch(apiUrl(path), {
    ...init,
    headers,
    credentials: "include",
    cache: "no-store",
  });
  if (!response.ok) {
    const payload = (await response.json().catch(() => null)) as {
      detail?: string | Array<{ msg?: string }>;
      error?: { message?: string };
    } | null;
    const detail = Array.isArray(payload?.detail)
      ? payload.detail
          .map((item) => item.msg)
          .filter(Boolean)
          .join(". ")
      : payload?.detail;
    throw new ApiError(
      payload?.error?.message ?? detail ?? "The request could not be completed.",
      response.status,
    );
  }
  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

export const api = {
  advancedInsights: (
    token: string,
    workspaceId: string,
    draft: string,
    alternativeDraft: string,
    platform: Platform,
  ) =>
    request<AdvancedReport>(`/workspaces/${workspaceId}/ml/advanced`, token, {
      method: "POST",
      body: JSON.stringify({ draft, alternative_draft: alternativeDraft, platform }),
    }),
  mlInsights: (token: string, workspaceId: string, draft: string, platform: Platform) =>
    request<MlReport>(`/workspaces/${workspaceId}/ml/insights`, token, {
      method: "POST",
      body: JSON.stringify({ draft, platform }),
    }),
  login: (email: string, password: string, admin = false) =>
    request<{
      access_token: string;
      expires_in: number;
      user: User;
      workspaces: Workspace[];
    }>(admin ? "/auth/admin/login" : "/auth/login", undefined, {
      method: "POST",
      body: JSON.stringify({ email, password }),
    }),
  register: (payload: {
    email: string;
    password: string;
    display_name: string;
    organization_name: string;
    workspace_name: string;
    timezone: string;
    account_type: "creator" | "business";
    brand_name: string;
  }) =>
    request<{
      user: User;
      workspace: Workspace;
      token: { access_token: string; expires_in: number } | null;
      account_status: string;
      payment_required: boolean;
      onboarding_token: string | null;
    }>("/auth/register", undefined, { method: "POST", body: JSON.stringify(payload) }),
  paymentInstructions: () =>
    request<{
      amount: string;
      currency: string;
      upi_id: string;
      qr_url: string;
      support_email: string;
      expires_in_days: number;
    }>("/auth/onboarding/payment-instructions"),
  submitPaymentPublic: (payload: {
    onboarding_token: string;
    utr_reference: string;
    note?: string;
  }) =>
    request<{ status: string; submitted_at: string | null }>(
      "/auth/onboarding/payment-submissions/public",
      undefined,
      {
        method: "POST",
        body: JSON.stringify(payload),
      },
    ),
  paymentStatusPublic: (onboardingToken: string) =>
    request<{ status: string; admin_note: string | null; submitted_at: string | null }>(
      "/auth/onboarding/payment-status/public",
      undefined,
      {
        method: "POST",
        body: JSON.stringify({ onboarding_token: onboardingToken }),
      },
    ),
  submitPaymentProof: async (token: string, utr: string, note: string, file: File) => {
    const form = new FormData();
    form.append("onboarding_token", token);
    if (utr) form.append("utr_reference", utr);
    if (note) form.append("note", note);
    form.append("file", file);
    const response = await fetch(apiUrl("/auth/onboarding/payment-submissions/public/proof"), {
      method: "POST",
      body: form,
    });
    if (!response.ok) throw new ApiError("Payment proof upload failed.", response.status);
    return (await response.json()) as { status: string; submitted_at: string | null };
  },
  adminPayments: (token: string) =>
    request<PaymentSubmission[]>("/auth/admin/payment-submissions", token),
  adminOverview: (token: string) => request<AdminOverview>("/auth/admin/overview", token),
  reviewPayment: (token: string, id: string, decision: "approve" | "reject", note?: string) =>
    request<{ status: string }>(`/auth/admin/payment-submissions/${id}/${decision}`, token, {
      method: "POST",
      body: JSON.stringify({ note: note || null }),
    }),
  me: (token: string) => request<User>("/auth/me", token),
  updateProfile: (
    token: string,
    payload: Pick<User, "display_name" | "email" | "account_type" | "brand_name" | "avatar_url">,
  ) => request<User>("/auth/me", token, { method: "PATCH", body: JSON.stringify(payload) }),
  changePassword: (token: string, currentPassword: string, newPassword: string) =>
    request<void>("/auth/change-password", token, {
      method: "POST",
      body: JSON.stringify({ current_password: currentPassword, new_password: newPassword }),
    }),
  logout: () => request<void>("/auth/logout", undefined, { method: "POST" }),
  workspaces: (token: string) => request<Workspace[]>("/workspaces", token),
  brands: (token: string, workspaceId: string) =>
    request<Brand[]>(`/workspaces/${workspaceId}/brands`, token),
  createBrand: (
    token: string,
    workspaceId: string,
    payload: Omit<Brand, "id" | "workspace_id" | "slug" | "created_at" | "updated_at">,
  ) =>
    request<Brand>(`/workspaces/${workspaceId}/brands`, token, {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  documents: (token: string, workspaceId: string) =>
    request<KnowledgeDocument[]>(`/workspaces/${workspaceId}/knowledge/documents`, token),
  ingest: (token: string, workspaceId: string, payload: Record<string, unknown>) =>
    request<{ document: KnowledgeDocument; chunks_created: number; deduplicated: boolean }>(
      `/workspaces/${workspaceId}/knowledge/documents`,
      token,
      { method: "POST", body: JSON.stringify(payload) },
    ),
  searchKnowledge: (token: string, workspaceId: string, payload: Record<string, unknown>) =>
    request<{ citations: Citation[] }>(`/workspaces/${workspaceId}/knowledge/search`, token, {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  campaigns: (token: string, workspaceId: string) =>
    request<Campaign[]>(`/workspaces/${workspaceId}/campaigns`, token),
  createCampaign: (token: string, workspaceId: string, payload: Record<string, unknown>) =>
    request<Campaign>(`/workspaces/${workspaceId}/campaigns`, token, {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  generateCampaign: (token: string, workspaceId: string, campaignId: string, feedback?: string) =>
    request<CampaignGeneration>(
      `/workspaces/${workspaceId}/campaigns/${campaignId}/generate`,
      token,
      {
        method: "POST",
        body: JSON.stringify({ feedback: feedback || null }),
      },
    ),
  streamModel: async (
    token: string,
    workspaceId: string,
    payload: Record<string, unknown>,
    onToken?: (token: string) => void,
  ): Promise<string> => {
    const headers = new Headers({ "Content-Type": "application/json" });
    if (token !== "cookie") headers.set("Authorization", `Bearer ${token}`);
    const response = await fetch(
      apiUrl(`/workspaces/${workspaceId}/models/local/generate/stream`),
      {
        method: "POST",
        headers,
        credentials: "include",
        cache: "no-store",
        body: JSON.stringify(payload),
      },
    );
    if (!response.ok || !response.body) {
      throw new ApiError("Live model streaming is unavailable.", response.status);
    }
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    let content = "";
    const consume = (line: string) => {
      if (!line.startsWith("data: ")) return;
      const value = line.slice(6).trim();
      if (value === "[DONE]") return;
      try {
        const event = JSON.parse(value) as { token?: string; message?: string };
        if (event.message) throw new Error(event.message);
        if (event.token) {
          content += event.token;
          onToken?.(content);
        }
      } catch (error) {
        if (error instanceof SyntaxError) return;
        throw error;
      }
    };
    while (true) {
      const chunk = await reader.read();
      buffer += decoder.decode(chunk.value ?? new Uint8Array(), { stream: !chunk.done });
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";
      for (const line of lines) consume(line.trim());
      if (chunk.done) break;
    }
    if (buffer.trim()) consume(buffer.trim());
    return content;
  },
  decideCampaign: (
    token: string,
    workspaceId: string,
    campaignId: string,
    decision: "approve" | "reject",
    feedback?: string,
  ) =>
    request<CampaignGeneration>(
      `/workspaces/${workspaceId}/campaigns/${campaignId}/decision`,
      token,
      {
        method: "POST",
        body: JSON.stringify({ decision, feedback: feedback || null }),
      },
    ),
  variants: (token: string, workspaceId: string, campaignId: string) =>
    request<ContentVariant[]>(`/workspaces/${workspaceId}/campaigns/${campaignId}/variants`, token),
  media: (token: string, workspaceId: string) =>
    request<MediaAsset[]>(`/workspaces/${workspaceId}/media/assets`, token),
  uploadMedia: async (
    token: string,
    workspaceId: string,
    campaignId: string | null,
    file: File,
  ) => {
    const form = new FormData();
    form.append("file", file);
    const response = await fetch(
      apiUrl(
        `/workspaces/${workspaceId}/media/assets/upload${campaignId ? `?campaign_id=${campaignId}` : ""}`,
      ),
      {
        method: "POST",
        body: form,
        credentials: "include",
        headers: token !== "cookie" ? { Authorization: `Bearer ${token}` } : undefined,
      },
    );
    if (!response.ok) throw new ApiError("Media upload failed.", response.status);
    return (await response.json()) as MediaAsset;
  },
  saveAssetCaption: (token: string, workspaceId: string, assetId: string, caption: string) =>
    request<MediaAsset>(`/workspaces/${workspaceId}/media/assets/${assetId}/caption`, token, {
      method: "PATCH",
      body: JSON.stringify({ caption }),
    }),
  extractCaption: async (token: string, workspaceId: string, file: File) => {
    if (file.size > 2 * 1024 * 1024) throw new Error("Choose a file of 2 MB or smaller.");
    const form = new FormData();
    form.append("file", file);
    const response = await fetch(apiUrl(`/workspaces/${workspaceId}/media/captions/extract`), {
      method: "POST",
      body: form,
      credentials: "include",
      headers: token !== "cookie" ? { Authorization: `Bearer ${token}` } : undefined,
    });
    if (!response.ok) {
      const body = await response.json().catch(() => ({}));
      throw new Error(
        body.detail?.message ||
          (typeof body.detail === "string" ? body.detail : body.error?.message) ||
          "File could not be read. Use a text PDF, UTF-8 TXT, or Markdown file.",
      );
    }
    return (await response.json()) as { text: string; filename: string };
  },
  attachMedia: (token: string, workspaceId: string, assetId: string, campaignId: string) =>
    request<MediaAsset>(`/workspaces/${workspaceId}/media/assets/${assetId}/attach`, token, {
      method: "POST",
      body: JSON.stringify({ campaign_id: campaignId }),
    }),
  generateImage: (token: string, workspaceId: string, payload: Record<string, unknown>) =>
    request<{ assets: MediaAsset[] }>(`/workspaces/${workspaceId}/media/images/generate`, token, {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  composeVideo: (token: string, workspaceId: string, payload: Record<string, unknown>) =>
    request<{ assets: MediaAsset[] }>(`/workspaces/${workspaceId}/media/videos/compose`, token, {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  accounts: (token: string, workspaceId: string) =>
    request<SocialAccount[]>(`/workspaces/${workspaceId}/publishing/accounts`, token),
  connectAccount: (token: string, workspaceId: string, payload: Record<string, unknown>) =>
    request<SocialAccount>(`/workspaces/${workspaceId}/publishing/accounts`, token, {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  oauthAuthorize: (
    token: string,
    workspaceId: string,
    provider: Extract<Platform, "facebook" | "instagram" | "threads" | "linkedin" | "youtube">,
  ) =>
    request<{ provider: string; authorization_url: string; expires_in: number }>(
      `/workspaces/${workspaceId}/publishing/oauth/${provider}/authorize`,
      token,
    ),
  oauthRefresh: (
    token: string,
    workspaceId: string,
    provider: Extract<Platform, "linkedin" | "youtube">,
    accountId: string,
  ) =>
    request<{ account_id: string; status: string; access_token_expires_at: string | null }>(
      `/workspaces/${workspaceId}/publishing/oauth/${provider}/accounts/${accountId}/refresh`,
      token,
      { method: "POST" },
    ),
  oauthRevoke: (
    token: string,
    workspaceId: string,
    provider: Extract<Platform, "facebook" | "instagram" | "threads" | "linkedin" | "youtube">,
    accountId: string,
  ) =>
    request<{ account_id: string; status: string }>(
      `/workspaces/${workspaceId}/publishing/oauth/${provider}/accounts/${accountId}/revoke`,
      token,
      { method: "POST" },
    ),
  publish: (token: string, workspaceId: string, payload: Record<string, unknown>) =>
    request<PublishJob>(`/workspaces/${workspaceId}/publishing/jobs`, token, {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  schedule: (token: string, workspaceId: string, payload: Record<string, unknown>) =>
    request<ScheduledPost>(`/workspaces/${workspaceId}/operations/schedule`, token, {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  scheduled: (token: string, workspaceId: string) =>
    request<ScheduledPost[]>(`/workspaces/${workspaceId}/operations/schedule`, token),
  cancelScheduled: (token: string, workspaceId: string, postId: string) =>
    request<ScheduledPost>(
      `/workspaces/${workspaceId}/operations/schedule/${postId}/cancel`,
      token,
      { method: "POST" },
    ),
  reschedule: (token: string, workspaceId: string, postId: string, scheduledFor: string) =>
    request<ScheduledPost>(
      `/workspaces/${workspaceId}/operations/schedule/${postId}/reschedule`,
      token,
      { method: "POST", body: JSON.stringify({ scheduled_for: scheduledFor }) },
    ),
  retryScheduled: (token: string, workspaceId: string, postId: string) =>
    request<ScheduledPost>(
      `/workspaces/${workspaceId}/operations/schedule/${postId}/retry`,
      token,
      { method: "POST" },
    ),
  metrics: (token: string, workspaceId: string) =>
    request<PostMetric[]>(`/workspaces/${workspaceId}/operations/metrics`, token),
};
