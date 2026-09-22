/* biome-ignore-all lint/a11y/useButtonType: interactive buttons are outside submit forms. */
/* biome-ignore-all lint/a11y/noLabelWithoutControl: Field wraps its control component. */
"use client";

import {
  ArrowRight,
  BrainCircuit,
  CalendarDays,
  Check,
  CircleAlert,
  Eye,
  EyeOff,
  FileText,
  Image,
  LogOut,
  Menu,
  Plus,
  RefreshCw,
  Search,
  Send,
  ShieldCheck,
  Sparkles,
  Upload,
  UserRound,
  X,
} from "lucide-react";
import { AnimatePresence, MotionConfig, motion } from "motion/react";
import NextImage from "next/image";
import {
  type ChangeEvent,
  type CSSProperties,
  type FormEvent,
  type MouseEvent,
  type ReactNode,
  useCallback,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from "react";
import {
  AiOrb,
  CommandPalette,
  DepthCard,
  Onboarding,
  ParticleField,
  Reveal,
  SoundToggle,
  TypewriterText,
  VoiceIndicator,
  VoiceInputButton,
} from "@/components/advanced-ui";
import { GrainOverlay } from "@/components/background/grain-overlay";
import { HeroVideo } from "@/components/background/hero-video";
import { WebglBackground } from "@/components/background/webgl-background";
import {
  AreaChart,
  BarChart,
  BubbleChart,
  CalendarHeatmap,
  CandlestickChart,
  ChartFrame,
  ComboChart,
  DonutChart,
  DotPlot,
  FunnelChart,
  GaugeChart,
  GroupedBarChart,
  HeatmapChart,
  HorizontalBarChart,
  LineChart,
  LollipopChart,
  PieChart,
  PolarAreaChart,
  ProgressRing,
  RadarChart,
  RadialBarChart,
  ScatterChart,
  Sparkline,
  StackedBarChart,
  StreamChart,
  TreemapChart,
  WaterfallChart,
} from "@/components/charts";
import { Reveal3D } from "@/components/depth";
import { Button } from "@/components/ui/button";
import {
  type AdminOverview,
  api,
  type Brand,
  type Campaign,
  type ContentVariant,
  type KnowledgeDocument,
  type MediaAsset,
  type PaymentSubmission,
  type Platform,
  type PostMetric,
  type ScheduledPost,
  type SocialAccount,
  type User,
  type Workspace,
} from "@/lib/api";
import { overlayFade, variantSwap } from "@/lib/motion";
import { cn } from "@/lib/utils";

// Cursor-follow glow — writes pointer position as CSS custom properties so
// the glow itself stays CSS-driven (no re-renders on mouse move).
function handleGlow(event: MouseEvent<HTMLElement>) {
  const rect = event.currentTarget.getBoundingClientRect();
  event.currentTarget.style.setProperty(
    "--mx",
    `${((event.clientX - rect.left) / rect.width) * 100}%`,
  );
  event.currentTarget.style.setProperty(
    "--my",
    `${((event.clientY - rect.top) / rect.height) * 100}%`,
  );
}

type View = "overview" | "campaigns" | "brain" | "media" | "publishing" | "analytics" | "admin";
const browserSession = "cookie";
const legacyTokenKey = "vae.staging.access-token";
const platforms: Array<{ id: Platform; label: string }> = [
  "linkedin",
  "instagram",
  "threads",
  "youtube",
  "x",
  "facebook",
].map((id) => ({ id: id as Platform, label: id[0].toUpperCase() + id.slice(1) }));
const date = (value?: string | null) =>
  value
    ? new Intl.DateTimeFormat(undefined, {
        month: "short",
        day: "numeric",
        hour: "numeric",
        minute: "2-digit",
      }).format(new Date(value))
    : "—";
const initial = (value?: string | null) => value?.trim().charAt(0).toUpperCase() || "V";
const idempotency = () =>
  `vae-web-${typeof crypto !== "undefined" && "randomUUID" in crypto ? crypto.randomUUID() : Date.now()}`;

async function withFallback<T>(request: Promise<T>, fallback: T): Promise<T> {
  try {
    return await request;
  } catch {
    return fallback;
  }
}
function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="live-field">
      <span>{label}</span>
      {children}
    </label>
  );
}
function Status({ value }: { value: string }) {
  return (
    <span className={cn("live-status", `status-${value.replaceAll("_", "-")}`)}>
      {value.replaceAll("_", " ")}
    </span>
  );
}
function Empty({
  icon: Icon,
  title,
  body,
}: {
  icon: typeof FileText;
  title: string;
  body: string;
}) {
  return (
    <div className="live-empty">
      <Icon size={20} />
      <strong>{title}</strong>
      <p>{body}</p>
    </div>
  );
}

export function LiveWorkspace() {
  const [token, setToken] = useState<string | null>(null);
  const [mode, setMode] = useState<"login" | "register">("login");
  const [view, setView] = useState<View>("overview");
  const [sidebar, setSidebar] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [workspace, setWorkspace] = useState<Workspace | null>(null);
  const [brands, setBrands] = useState<Brand[]>([]);
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [documents, setDocuments] = useState<KnowledgeDocument[]>([]);
  const [assets, setAssets] = useState<MediaAsset[]>([]);
  const [accounts, setAccounts] = useState<SocialAccount[]>([]);
  const [scheduled, setScheduled] = useState<ScheduledPost[]>([]);
  const [metrics, setMetrics] = useState<PostMetric[]>([]);
  const [selected, setSelected] = useState("");
  const [variants, setVariants] = useState<ContentVariant[]>([]);
  const [streamPreview, setStreamPreview] = useState("");
  const [evidence, setEvidence] = useState<
    Array<{ chunk_id: string; document_title: string; score: number; excerpt: string }>
  >([]);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [name, setName] = useState("");
  const [org, setOrg] = useState("");
  const [accountType, setAccountType] = useState<"creator" | "business">("creator");
  const [profileOpen, setProfileOpen] = useState(false);
  const [profileName, setProfileName] = useState("");
  const [profileEmail, setProfileEmail] = useState("");
  const [profileBrand, setProfileBrand] = useState("");
  const [profileAvatar, setProfileAvatar] = useState("");
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [brandName, setBrandName] = useState("VAE");
  const [brandDescription, setBrandDescription] = useState(
    "Evidence-led GenAI content operations.",
  );
  const [sourceTitle, setSourceTitle] = useState("");
  const [sourceText, setSourceText] = useState("");
  const [query, setQuery] = useState("");
  const [campaignName, setCampaignName] = useState("");
  const [goal, setGoal] = useState("");
  const [product, setProduct] = useState("");
  const [audience, setAudience] = useState("");
  const [instructions, setInstructions] = useState("");
  const [selectedPlatforms, setSelectedPlatforms] = useState<Platform[]>(["linkedin"]);
  const [mediaPrompt, setMediaPrompt] = useState("");
  const [mediaMode, setMediaMode] = useState<"image" | "text">("image");
  const [generatedText, setGeneratedText] = useState("");
  const [uploadingMedia, setUploadingMedia] = useState(false);
  const [publishCampaign, setPublishCampaign] = useState("");
  const [publishAccounts, setPublishAccounts] = useState<string[]>([]);
  const [publishText, setPublishText] = useState("");
  const [scheduleAt, setScheduleAt] = useState("");
  const [paletteOpen, setPaletteOpen] = useState(false);
  const [tourOpen, setTourOpen] = useState(false);
  const [signOutOpen, setSignOutOpen] = useState(false);
  const [signingOut, setSigningOut] = useState(false);
  const [onboarding, setOnboarding] = useState<{ token: string; email: string } | null>(null);
  const [paymentInfo, setPaymentInfo] = useState<{
    amount: string;
    currency: string;
    upi_id: string;
    qr_url: string;
    support_email: string;
    expires_in_days: number;
  } | null>(null);
  const [paymentUtr, setPaymentUtr] = useState("");
  const [paymentNote, setPaymentNote] = useState("");
  const [paymentProof, setPaymentProof] = useState<File | null>(null);
  const [paymentStatus, setPaymentStatus] = useState<{
    status: string;
    admin_note: string | null;
  } | null>(null);
  const [paymentSubmissions, setPaymentSubmissions] = useState<PaymentSubmission[]>([]);
  const [adminOverview, setAdminOverview] = useState<AdminOverview | null>(null);
  const [theme, setTheme] = useState<"dark" | "light">(() => {
    if (typeof window === "undefined") return "dark";
    return window.localStorage.getItem("vae.theme") === "light" ? "light" : "dark";
  });

  useEffect(() => {
    if (!notice) return;
    const timer = window.setTimeout(() => setNotice(null), 5000);
    return () => window.clearTimeout(timer);
  }, [notice]);

  useEffect(() => {
    if (!error) return;
    const timer = window.setTimeout(() => setError(null), 7000);
    return () => window.clearTimeout(timer);
  }, [error]);

  useEffect(() => {
    if (!user) return;
    setProfileName(user.display_name);
    setProfileEmail(user.email);
    setProfileBrand(user.brand_name ?? "");
    setProfileAvatar(user.avatar_url ?? "");
  }, [user]);
  const [themeWipe, setThemeWipe] = useState<"dark" | "light" | null>(null);
  const [soundEnabled, setSoundEnabled] = useState(false);
  const [pulse, setPulse] = useState(0);
  const [scrolled, setScrolled] = useState(false);
  const [metricOrder, setMetricOrder] = useState(["assets", "channels", "scheduled", "engagement"]);
  const [dragMetric, setDragMetric] = useState<string | null>(null);
  // The dashboard scrolls inside `.live-content`, not the window.
  const contentRef = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    // Each sidebar destination starts at its heading, including a return to
    // Overview after scrolling a longer view.
    if (!view) return;
    if (contentRef.current) contentRef.current.scrollTop = 0;
    setScrolled(false);
  }, [view]);
  const currentCampaign = campaigns.find((item) => item.id === selected);
  const currentVariant = variants.find((item) => item.status === "approved") ?? variants[0];
  const playTone = useCallback(() => {
    if (!soundEnabled || typeof window === "undefined") return;
    const AudioContextClass =
      window.AudioContext ||
      (window as Window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!AudioContextClass) return;
    const context = new AudioContextClass();
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.frequency.value = 660;
    gain.gain.setValueAtTime(0.0001, context.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.035, context.currentTime + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + 0.18);
    oscillator.connect(gain).connect(context.destination);
    oscillator.start();
    oscillator.stop(context.currentTime + 0.2);
  }, [soundEnabled]);
  const toggleTheme = useCallback(() => {
    const next = theme === "dark" ? "light" : "dark";
    setTheme(next);
    setThemeWipe(next);
    window.setTimeout(() => setThemeWipe(null), 760);
  }, [theme]);
  const reset = useCallback(() => {
    // Remove only the legacy pre-cookie token. New browser sessions are
    // HTTP-only and therefore inaccessible to JavaScript by design.
    window.localStorage.removeItem(legacyTokenKey);
    setToken(null);
    setUser(null);
    setWorkspace(null);
    setBrands([]);
    setCampaigns([]);
    setDocuments([]);
    setAssets([]);
    setAccounts([]);
    setScheduled([]);
    setMetrics([]);
    setVariants([]);
  }, []);
  const run = async (name: string, task: () => Promise<void>) => {
    setBusy(name);
    setError(null);
    try {
      await task();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "The operation failed.");
    } finally {
      setBusy(null);
    }
  };
  const load = useCallback(
    async (accessToken: string) => {
      setBusy("load");
      try {
        const [me, workspaces] = await Promise.all([
          api.me(accessToken),
          api.workspaces(accessToken),
        ]);
        const nextWorkspace = workspaces[0];
        if (!nextWorkspace) throw new Error("No active workspace found.");
        // Let people enter the control room as soon as identity and workspace
        // context are known. The secondary resources populate in the
        // background rather than making sign-in feel like a full-page wait.
        setUser(me);
        setWorkspace(nextWorkspace);
        setBusy(null);
        // Secondary panels must never block the control room. A single
        // unavailable media/metrics endpoint previously left the entire
        // overview in a blank loading state. Each panel now degrades to an
        // honest empty collection while identity and navigation stay usable.
        const [
          nextBrands,
          nextCampaigns,
          nextDocuments,
          nextAssets,
          nextAccounts,
          nextScheduled,
          nextMetrics,
        ] = await Promise.all([
          withFallback(api.brands(accessToken, nextWorkspace.id), []),
          withFallback(api.campaigns(accessToken, nextWorkspace.id), []),
          withFallback(api.documents(accessToken, nextWorkspace.id), []),
          withFallback(api.media(accessToken, nextWorkspace.id), []),
          withFallback(api.accounts(accessToken, nextWorkspace.id), []),
          withFallback(api.scheduled(accessToken, nextWorkspace.id), []),
          withFallback(api.metrics(accessToken, nextWorkspace.id), []),
        ]);
        let resolvedBrands = nextBrands;
        let resolvedCampaigns = nextCampaigns;
        if (!me.is_admin && resolvedCampaigns.length === 0) {
          const foundationBrand =
            resolvedBrands[0] ??
            (await api.createBrand(accessToken, nextWorkspace.id, {
              name: me.brand_name || me.display_name,
              description: "Private publishing profile managed by VAE.",
              website_url: null,
              industry: null,
              tone_attributes: [],
              target_audiences: [],
              preferred_ctas: [],
              preferred_hashtags: [],
              status: "active",
            }));
          const publishingContext = await api.createCampaign(accessToken, nextWorkspace.id, {
            brand_id: foundationBrand.id,
            name: "Media publishing",
            goal: "Create and publish media",
            product_service: me.brand_name || me.display_name,
            audience: "Social audience",
            instructions: "Internal publishing context",
            platforms: ["instagram"],
            media_types: ["text", "image", "video"],
            publishing_mode: "manual",
          });
          resolvedBrands = [foundationBrand];
          resolvedCampaigns = [publishingContext];
        }
        setBrands(resolvedBrands);
        setCampaigns(resolvedCampaigns);
        setDocuments(nextDocuments);
        setAssets(nextAssets);
        setAccounts(nextAccounts);
        setScheduled(nextScheduled);
        setMetrics(nextMetrics);
        setSelected((value) => value || resolvedCampaigns[0]?.id || "");
        setPublishCampaign((value) => value || resolvedCampaigns[0]?.id || "");
        setPublishAccounts((value) =>
          value.length ? value : nextAccounts[0]?.id ? [nextAccounts[0].id] : [],
        );
      } catch (caught) {
        if (caught instanceof Error && caught.message.includes("401")) reset();
        setError(caught instanceof Error ? caught.message : "Unable to load workspace.");
      } finally {
        setBusy(null);
      }
    },
    [reset],
  );
  useEffect(() => {
    window.localStorage.removeItem(legacyTokenKey);
    api
      .me(browserSession)
      .then(() => setToken(browserSession))
      .catch(() => setToken(null));
  }, []);
  useEffect(() => {
    if (token) void load(token);
  }, [token, load]);
  useEffect(() => {
    if (!onboarding || !paymentStatus || paymentStatus.status === "approved") return;
    const refreshStatus = async () => {
      try {
        const result = await api.paymentStatusPublic(onboarding.token);
        setPaymentStatus({ status: result.status, admin_note: result.admin_note });
      } catch {
        // A temporary network failure must not discard the registration flow.
      }
    };
    const timer = window.setInterval(() => void refreshStatus(), 5000);
    void refreshStatus();
    return () => window.clearInterval(timer);
  }, [onboarding, paymentStatus]);
  useEffect(() => {
    if (token && workspace && selected)
      void api
        .variants(token, workspace.id, selected)
        .then(setVariants)
        .catch(() => setVariants([]));
  }, [token, workspace, selected]);
  useEffect(() => {
    const savedOrder = window.localStorage.getItem("vae.metric-order");
    if (savedOrder) {
      try {
        const parsed = JSON.parse(savedOrder) as string[];
        const allowed = new Set(["assets", "channels", "scheduled", "engagement"]);
        if (parsed.length === 4 && parsed.every((item) => allowed.has(item))) {
          setMetricOrder(parsed);
        }
      } catch {
        // Ignore stale local preferences.
      }
    }
    setTourOpen(window.localStorage.getItem("vae.tour-complete") !== "1");
    const query = new URLSearchParams(window.location.search);
    const oauthResult = query.get("oauth");
    if (oauthResult === "connected") {
      setNotice("Publisher connected securely. Refreshing account status…");
      window.history.replaceState({}, "", window.location.pathname);
    } else if (oauthResult === "error") {
      setError(query.get("message") ?? "The publisher connection was not completed.");
      window.history.replaceState({}, "", window.location.pathname);
    }
    const onKeyDown = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setPaletteOpen(true);
      }
      if (event.key === "Escape") {
        setPaletteOpen(false);
        setTourOpen(false);
        setSignOutOpen(false);
      }
    };
    const onScroll = () => setScrolled((contentRef.current?.scrollTop ?? 0) > 24);
    const scrollContainer = contentRef.current;
    window.addEventListener("keydown", onKeyDown);
    scrollContainer?.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => {
      window.removeEventListener("keydown", onKeyDown);
      scrollContainer?.removeEventListener("scroll", onScroll);
    };
  }, []);
  useLayoutEffect(() => {
    document.documentElement.dataset.theme = theme;
    document.documentElement.style.colorScheme = theme;
    window.localStorage.setItem("vae.theme", theme);
  }, [theme]);
  useEffect(() => {
    window.localStorage.setItem("vae.metric-order", JSON.stringify(metricOrder));
  }, [metricOrder]);
  const authenticate = async (event: FormEvent) => {
    event.preventDefault();
    setBusy("auth");
    setError(null);
    try {
      const result =
        mode === "login"
          ? await api.login(email, password)
          : await api.register({
              email,
              password,
              display_name: name,
              organization_name: org,
              workspace_name: "Content Studio",
              account_type: accountType,
              brand_name: org,
              timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC",
            });
      if (
        mode === "register" &&
        "account_status" in result &&
        result.account_status !== "approved"
      ) {
        if (result.onboarding_token) {
          setOnboarding({ token: result.onboarding_token, email });
          setPaymentInfo(await api.paymentInstructions());
          setPaymentStatus({ status: result.account_status, admin_note: null });
          setError(null);
        } else {
          setError("Account created. Complete payment verification before signing in.");
          setMode("login");
        }
      } else {
        // The browser intentionally uses the HTTP-only cookie set by the response.
        setToken(browserSession);
      }
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Authentication failed.");
    } finally {
      setBusy(null);
    }
  };
  const submitPayment = async (event?: FormEvent) => {
    event?.preventDefault();
    if (!onboarding || (!paymentUtr.trim() && !paymentProof)) return;
    setBusy("auth");
    setError(null);
    try {
      let result: { status: string; admin_note?: string | null };
      if (paymentProof) {
        result = await api.submitPaymentProof(
          onboarding.token,
          paymentUtr.trim(),
          paymentNote.trim(),
          paymentProof,
        );
      } else {
        result = await api.submitPaymentPublic({
          onboarding_token: onboarding.token,
          utr_reference: paymentUtr.trim(),
          note: paymentNote.trim() || undefined,
        });
      }
      setPaymentStatus({ status: result.status, admin_note: result.admin_note ?? null });
      setNotice("Payment submitted. This page will update automatically after review.");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Payment submission failed.");
    } finally {
      setBusy(null);
    }
  };
  const loadPaymentSubmissions = async () => {
    if (!token || !user?.is_admin) return;
    await run("admin-payments", async () => {
      const [payments, overview] = await Promise.all([
        api.adminPayments(token),
        api.adminOverview(token),
      ]);
      setPaymentSubmissions(payments);
      setAdminOverview(overview);
    });
  };
  const saveProfile = async (event: FormEvent) => {
    event.preventDefault();
    if (!token || !user) return;
    await run("profile", async () => {
      const updated = await api.updateProfile(token, {
        display_name: profileName,
        email: profileEmail,
        account_type: user.account_type,
        brand_name: profileBrand || null,
        avatar_url: profileAvatar || null,
      });
      if (currentPassword || newPassword) {
        if (!currentPassword || newPassword.length < 8) {
          throw new Error(
            "Enter your current password and a new password of at least 8 characters.",
          );
        }
        await api.changePassword(token, currentPassword, newPassword);
      }
      setUser(updated);
      setCurrentPassword("");
      setNewPassword("");
      setProfileOpen(false);
      setNotice("Profile updated successfully.");
    });
  };
  const reviewPayment = async (item: PaymentSubmission, decision: "approve" | "reject") => {
    if (!token) return;
    const note = decision === "reject" ? window.prompt("Reason for rejection") : undefined;
    if (decision === "reject" && !note) return;
    await run(`review-${item.id}`, async () => {
      await api.reviewPayment(token, item.id, decision, note ?? undefined);
      await loadPaymentSubmissions();
      setNotice(`Payment ${decision}d.`);
    });
  };
  const createCampaign = async (event: FormEvent) => {
    event.preventDefault();
    if (!token || !workspace) {
      setError("Your workspace is still loading. Please try again.");
      return;
    }
    if (!selectedPlatforms.length) {
      setError("Select at least one target channel.");
      return;
    }
    await run("campaign", async () => {
      const campaign = await api.createCampaign(token, workspace.id, {
        brand_id: brands[0]?.id ?? null,
        name: campaignName,
        goal,
        product_service: product,
        audience,
        instructions,
        platforms: selectedPlatforms,
        media_types: ["text", "image"],
        publishing_mode: "manual",
      });
      const [generated] = await Promise.all([
        api.generateCampaign(token, workspace.id, campaign.id),
        api
          .streamModel(
            token,
            workspace.id,
            {
              prompt: `Create a concise campaign direction for ${campaignName}. Goal: ${goal}. Audience: ${audience}. Product: ${product}.`,
              system_prompt:
                "You are VAE's campaign strategist. Keep the direction grounded, concise, and reviewable.",
              max_tokens: 500,
            },
            setStreamPreview,
          )
          .catch(() => ""),
      ]);
      setCampaigns((items) => [generated.campaign, ...items]);
      setSelected(campaign.id);
      setPublishCampaign(campaign.id);
      setVariants(generated.variants);
      setNotice("Review-ready variants generated.");
      setPulse((value) => value + 1);
      playTone();
    });
  };
  const decide = async (decision: "approve" | "reject") => {
    if (!token || !workspace || !currentCampaign) return;
    await run(decision, async () => {
      const generated = await api.decideCampaign(token, workspace.id, currentCampaign.id, decision);
      setCampaigns((items) =>
        items.map((item) => (item.id === currentCampaign.id ? generated.campaign : item)),
      );
      setVariants(generated.variants);
      setNotice(
        decision === "approve" ? "Campaign approved for publishing." : "Changes requested.",
      );
      setPulse((value) => value + 1);
      playTone();
    });
  };
  const createBrand = async (event: FormEvent) => {
    event.preventDefault();
    if (!token || !workspace) return;
    await run("brand", async () => {
      const brand = await api.createBrand(token, workspace.id, {
        name: brandName,
        description: brandDescription,
        website_url: null,
        industry: "Artificial intelligence",
        tone_attributes: ["clear", "confident", "evidence-led"],
        target_audiences: ["marketing teams"],
        preferred_ctas: ["Explore VAE"],
        preferred_hashtags: ["#VAE", "#AgenticAI"],
        status: "active",
      });
      setBrands((items) => [brand, ...items]);
    });
  };
  const ingest = async (event: FormEvent) => {
    event.preventDefault();
    if (!token || !workspace) return;
    await run("ingest", async () => {
      const result = await api.ingest(token, workspace.id, {
        title: sourceTitle,
        source_type: "markdown",
        content: sourceText,
        brand_id: brands[0]?.id ?? null,
      });
      setDocuments((items) => [result.document, ...items]);
      setSourceTitle("");
      setSourceText("");
      setNotice(`${result.chunks_created} evidence chunks indexed.`);
    });
  };
  const searchBrain = async (event: FormEvent) => {
    event.preventDefault();
    if (!token || !workspace) return;
    await run("search", async () => {
      const result = await api.searchKnowledge(token, workspace.id, {
        query,
        brand_id: brands[0]?.id ?? null,
      });
      setEvidence(result.citations);
    });
  };
  const createImage = async (event: FormEvent) => {
    event.preventDefault();
    if (!token || !workspace) return;
    await run("image", async () => {
      const result = await api.generateImage(token, workspace.id, {
        campaign_id: null,
        prompt: mediaPrompt,
        platforms: ["instagram"],
        aspect_ratio: "1:1",
        brand_overlay: true,
        brand_text: brands[0]?.name ?? "VAE",
      });
      setAssets((items) => [...result.assets, ...items]);
      setMediaPrompt("");
      setNotice("Visual asset generated.");
      setPulse((value) => value + 1);
      playTone();
    });
  };
  const createText = async () => {
    if (!token || !workspace || mediaPrompt.trim().length < 3) return;
    setGeneratedText("");
    await run("text", async () => {
      const content = await api.streamModel(
        token,
        workspace.id,
        {
          prompt: mediaPrompt,
          system_prompt:
            "Create polished social-media copy. Return only the publish-ready copy and relevant hashtags.",
          max_tokens: 700,
        },
        setGeneratedText,
      );
      setGeneratedText(content);
      setPublishText(content);
      setNotice("Text generated and copied into publishing.");
    });
  };
  const uploadMedia = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file || !token || !workspace) return;
    setUploadingMedia(true);
    setError(null);
    try {
      const asset = await api.uploadMedia(token, workspace.id, "", file);
      setAssets((items) => [asset, ...items]);
      setNotice(`${file.name} uploaded to the media library.`);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Media upload failed.");
    } finally {
      setUploadingMedia(false);
      event.target.value = "";
    }
  };
  const downloadAsset = async (asset: MediaAsset) => {
    if (!token || !asset.download_url) return;
    await run(`download-${asset.id}`, async () => {
      const response = await fetch(asset.download_url as string, {
        credentials: "include",
        headers: token !== browserSession ? { Authorization: `Bearer ${token}` } : undefined,
      });
      if (!response.ok) throw new Error("The asset download could not be completed.");
      const objectUrl = URL.createObjectURL(await response.blob());
      const link = document.createElement("a");
      link.href = objectUrl;
      link.download = asset.filename;
      link.click();
      URL.revokeObjectURL(objectUrl);
    });
  };
  const startOAuth = async (
    provider: Extract<Platform, "facebook" | "instagram" | "threads" | "linkedin" | "youtube">,
  ) => {
    if (!token || !workspace) return;
    await run(`oauth-${provider}`, async () => {
      const result = await api.oauthAuthorize(token, workspace.id, provider);
      window.location.assign(result.authorization_url);
    });
  };
  const refreshAccount = async (account: SocialAccount) => {
    if (!token || !workspace || (account.platform !== "linkedin" && account.platform !== "youtube"))
      return;
    const provider = account.platform;
    await run(`refresh-${account.id}`, async () => {
      await api.oauthRefresh(token, workspace.id, provider, account.id);
      setAccounts((items) =>
        items.map((item) => (item.id === account.id ? { ...item, status: "connected" } : item)),
      );
      setNotice(`${account.display_name} token refreshed.`);
    });
  };
  const revokeAccount = async (account: SocialAccount) => {
    if (!token || !workspace) return;
    await run(`revoke-${account.id}`, async () => {
      await api.oauthRevoke(
        token,
        workspace.id,
        account.platform as Exclude<Platform, "x">,
        account.id,
      );
      setAccounts((items) =>
        items.map((item) => (item.id === account.id ? { ...item, status: "revoked" } : item)),
      );
      setNotice(`${account.display_name} disconnected.`);
    });
  };
  const publish = async (shouldSchedule: boolean) => {
    if (
      !token ||
      !workspace ||
      !publishCampaign ||
      !publishAccounts.length ||
      !(publishText || currentVariant?.caption)
    )
      return;
    await run(shouldSchedule ? "schedule" : "publish", async () => {
      const results = await Promise.all(
        publishAccounts.map(async (accountId) => {
          const payload = {
            campaign_id: publishCampaign,
            social_account_id: accountId,
            idempotency_key: idempotency(),
            text: publishText || currentVariant?.caption || "",
            media_urls: [],
          };
          if (shouldSchedule) {
            return api.schedule(token, workspace.id, {
              ...payload,
              scheduled_for: new Date(scheduleAt || Date.now() + 86_400_000).toISOString(),
            });
          }
          return api.publish(token, workspace.id, payload);
        }),
      );
      if (shouldSchedule) {
        setScheduled((items) => [...(results as ScheduledPost[]), ...items]);
        setNotice(`${results.length} channel${results.length === 1 ? "" : "s"} scheduled.`);
      } else {
        const failed = results.filter((item) => item.status === "failed").length;
        setNotice(
          failed
            ? `${results.length - failed} published, ${failed} failed.`
            : `${results.length} channel${results.length === 1 ? "" : "s"} published.`,
        );
      }
    });
  };
  const cancelScheduled = async (postId: string) => {
    if (!token || !workspace) return;
    await run(`cancel-${postId}`, async () => {
      const item = await api.cancelScheduled(token, workspace.id, postId);
      setScheduled((items) => items.map((current) => (current.id === item.id ? item : current)));
      setNotice("Scheduled post cancelled.");
    });
  };
  const retryScheduled = async (postId: string) => {
    if (!token || !workspace) return;
    await run(`retry-${postId}`, async () => {
      const item = await api.retryScheduled(token, workspace.id, postId);
      setScheduled((items) => items.map((current) => (current.id === item.id ? item : current)));
      setNotice("Failed post returned to the delivery queue.");
    });
  };
  const reschedule = async (post: ScheduledPost) => {
    if (!token || !workspace) return;
    const next = window.prompt("Enter a future date/time (ISO format)", post.scheduled_for);
    if (!next) return;
    await run(`reschedule-${post.id}`, async () => {
      const item = await api.reschedule(token, workspace.id, post.id, new Date(next).toISOString());
      setScheduled((items) => items.map((current) => (current.id === item.id ? item : current)));
      setNotice(`Post rescheduled for ${date(item.scheduled_for)}.`);
    });
  };
  if (!token)
    return (
      <MotionConfig reducedMotion="user">
        <main className="live-auth">
          <WebglBackground />
          <HeroVideo />
          <div className="hero-video-overlay" aria-hidden="true" />
          <GrainOverlay />
          <motion.section
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
          >
            <div className="live-logo">
              <span />
              <b>VAE</b>
            </div>
            <p className="live-kicker">Campaign intelligence, grounded</p>
            <h1>Make every piece of content feel like your sharpest team made it.</h1>
            <p>
              Turn approved brand knowledge into evidence-backed, human-approved content operations.
            </p>
            <div className="live-auth-points">
              <span>
                <Check size={15} /> Brand-grounded generation
              </span>
              <span>
                <Check size={15} /> Reviewable evidence trail
              </span>
              <span>
                <Check size={15} /> Staged publishing control
              </span>
            </div>
          </motion.section>
          <motion.form
            className="live-auth-card"
            onSubmit={authenticate}
            onMouseMove={handleGlow}
            initial={{ opacity: 0, y: 16, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1], delay: 0.1 }}
          >
            {onboarding && paymentInfo ? (
              <div className="live-payment-card">
                {paymentStatus?.status === "approved" ? (
                  <motion.div
                    className="live-payment-success"
                    initial={{ opacity: 0, scale: 0.96 }}
                    animate={{ opacity: 1, scale: 1 }}
                  >
                    <span>
                      <Check size={26} />
                    </span>
                    <p className="live-kicker">Payment approved</p>
                    <h2>Your VAE account is ready.</h2>
                    <p>Your payment has been verified. You can now sign in to your account.</p>
                    <Button
                      type="button"
                      className="live-full-button"
                      onClick={() => {
                        setOnboarding(null);
                        setPaymentInfo(null);
                        setPaymentStatus(null);
                        setPaymentUtr("");
                        setPaymentNote("");
                        setPaymentProof(null);
                        setMode("login");
                        setNotice("Payment approved. You can sign in now.");
                      }}
                    >
                      <ArrowRight size={15} /> Continue to sign in
                    </Button>
                  </motion.div>
                ) : (
                  <>
                    <p className="live-kicker">Payment verification</p>
                    <h2>Complete your registration</h2>
                    <p>Scan with GPay, Paytm, BHIM, or any UPI app.</p>
                    <NextImage
                      src={paymentInfo.qr_url || "/payments/vae-upi-qr.png"}
                      alt="VAE UPI payment QR"
                      className="live-payment-qr"
                      width={220}
                      height={220}
                      unoptimized
                      priority
                    />
                    <div className="live-payment-details">
                      <strong>
                        {paymentInfo.amount} {paymentInfo.currency}
                      </strong>
                      <code>
                        {paymentInfo.upi_id || "UPI ID will be configured by the administrator"}
                      </code>
                    </div>
                    {paymentStatus?.status === "under_review" ? (
                      <div className="live-payment-pending" role="status">
                        <span className="live-status-dot" />
                        <div>
                          <strong>Verification in progress</strong>
                          <p>
                            Keep this page open. It will update automatically when the administrator
                            completes the review.
                          </p>
                        </div>
                      </div>
                    ) : (
                      <>
                        {paymentStatus?.status === "rejected" && (
                          <div className="live-alert error">
                            <CircleAlert size={15} />
                            {paymentStatus.admin_note ||
                              "The payment could not be verified. Submit updated proof."}
                          </div>
                        )}
                        <input
                          value={paymentUtr}
                          onChange={(event) => setPaymentUtr(event.target.value)}
                          placeholder="UTR / transaction reference"
                        />
                        <input
                          value={paymentNote}
                          onChange={(event) => setPaymentNote(event.target.value)}
                          placeholder="Optional payment note"
                        />
                        <input
                          type="file"
                          accept="image/jpeg,image/png,image/webp"
                          onChange={(event) => setPaymentProof(event.target.files?.[0] ?? null)}
                        />
                        <Button
                          type="button"
                          className="live-full-button"
                          disabled={busy === "auth" || (!paymentUtr.trim() && !paymentProof)}
                          onClick={() => void submitPayment()}
                        >
                          Submit payment proof
                        </Button>
                      </>
                    )}
                  </>
                )}
              </div>
            ) : (
              <>
                <div className="live-tabs">
                  <button
                    type="button"
                    className={cn(mode === "login" && "active")}
                    onClick={() => setMode("login")}
                  >
                    Sign in
                  </button>
                  <button
                    type="button"
                    className={cn(mode === "register" && "active")}
                    onClick={() => setMode("register")}
                  >
                    Get started
                  </button>
                </div>
                <h2>{mode === "login" ? "Welcome back" : "Create your VAE account"}</h2>
                {notice && mode === "login" && (
                  <div className="live-alert success">
                    <Check size={15} /> {notice}
                  </div>
                )}
                {error && (
                  <div className="live-alert error">
                    <CircleAlert size={15} /> {error}
                  </div>
                )}
                {mode === "register" && (
                  <>
                    <Field label="Your name">
                      <input
                        required
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        placeholder="Jane Smith"
                      />
                    </Field>
                    <Field label="Product or brand name">
                      <input
                        required
                        value={org}
                        onChange={(e) => setOrg(e.target.value)}
                        placeholder="Acme Studio"
                      />
                    </Field>
                    <Field label="Account type">
                      <select
                        value={accountType}
                        onChange={(event) =>
                          setAccountType(event.target.value as "creator" | "business")
                        }
                      >
                        <option value="creator">Creator</option>
                        <option value="business">Business</option>
                      </select>
                    </Field>
                  </>
                )}
                <Field label="Email">
                  <input
                    required
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@company.com"
                  />
                </Field>
                <Field label="Password">
                  <span className="password-control">
                    <input
                      required
                      type={showPassword ? "text" : "password"}
                      minLength={1}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="Your password"
                    />
                    <button
                      type="button"
                      aria-label={showPassword ? "Hide password" : "Show password"}
                      onClick={() => setShowPassword((visible) => !visible)}
                    >
                      {showPassword ? <EyeOff size={17} /> : <Eye size={17} />}
                    </button>
                  </span>
                </Field>
                <Button type="submit" className="live-full-button" disabled={busy === "auth"}>
                  <ArrowRight className={cn(busy === "auth" && "live-spin")} size={15} />
                  {busy === "auth" ? "Signing in…" : mode === "login" ? "Sign in" : "Get started"}
                </Button>
              </>
            )}
            {onboarding && error && (
              <div className="live-alert error">
                <CircleAlert size={15} /> {error}
              </div>
            )}
          </motion.form>
        </main>
      </MotionConfig>
    );
  const nav = [
    { id: "overview" as View, label: "Home", icon: BrainCircuit },
    { id: "media" as View, label: "Create media", icon: Sparkles },
    { id: "publishing" as View, label: "Calendar & publishing", icon: CalendarDays },
    { id: "analytics" as View, label: "Analytics", icon: BrainCircuit },
    ...(user?.is_admin
      ? [{ id: "admin" as View, label: "Payment review", icon: ShieldCheck }]
      : []),
  ];
  const overview = (
    <>
      <Reveal className="live-hero live-glow" onMouseMove={handleGlow}>
        <ParticleField pulse={pulse} />
        <div>
          <p className="live-kicker">Your content home</p>
          <h1>Good to see you, {user?.display_name?.split(" ")[0] ?? "there"}.</h1>
          <p>
            <TypewriterText text="Create media, connect channels, and publish from one place." />
          </p>
        </div>
        <div className="live-hero-tools">
          <AiOrb state={busy === "load" ? "thinking" : notice ? "success" : "idle"} />
          <span className="live-connected">
            <i /> API connected
          </span>
          <VoiceIndicator />
        </div>
      </Reveal>
      <Reveal className="live-stats bento-grid">
        {metricOrder.map((metric) => {
          const metricData = {
            assets: [Image, "Media assets", assets.length, "in your library"],
            channels: [Send, "Connected channels", accounts.length, "ready to publish"],
            scheduled: [CalendarDays, "Scheduled", scheduled.length, "upcoming posts"],
            engagement: [
              Sparkles,
              "Engagement",
              metrics.reduce((sum, item) => sum + item.engagements, 0),
              "recorded interactions",
            ],
          }[metric] ?? [Sparkles, "Signals", 0, "awaiting data"];
          const Icon = metricData[0] as typeof BrainCircuit;
          return (
            <DepthCard
              key={metric}
              className="metric-card"
              onDragOver={(event) => event.preventDefault()}
              onDrop={() => {
                if (!dragMetric || dragMetric === metric) return;
                setMetricOrder((items) => {
                  const next = [...items];
                  const from = next.indexOf(dragMetric);
                  const to = next.indexOf(metric);
                  next.splice(from, 1);
                  next.splice(to, 0, dragMetric);
                  return next;
                });
                setDragMetric(null);
              }}
            >
              <button
                className="metric-drag-handle"
                draggable
                onDragStart={() => setDragMetric(metric)}
                aria-label={`Reorder ${metric}`}
              >
                <Icon size={18} />
              </button>
              <small>{metricData[1] as string}</small>
              <strong>{metricData[2] as number}</strong>
              <span>{metricData[3] as string}</span>
            </DepthCard>
          );
        })}
      </Reveal>
      <section className="live-panel overview-metrics">
        <div className="live-panel-head">
          <div>
            <p className="live-kicker">Distribution pulse</p>
            <h2>Provider performance</h2>
          </div>
          <button type="button" className="text-button" onClick={() => setView("analytics")}>
            Open analytics <ArrowRight size={14} />
          </button>
        </div>
        {metrics.length ? (
          <div className="overview-metric-grid">
            <div>
              <strong>
                {metrics.reduce((sum, item) => sum + item.impressions, 0).toLocaleString()}
              </strong>
              <span>impressions</span>
            </div>
            <div>
              <strong>
                {metrics.reduce((sum, item) => sum + item.engagements, 0).toLocaleString()}
              </strong>
              <span>engagements</span>
            </div>
            <div>
              <strong>{metrics.reduce((sum, item) => sum + item.likes, 0).toLocaleString()}</strong>
              <span>likes</span>
            </div>
            <div>
              <strong>{metrics.length}</strong>
              <span>snapshots</span>
            </div>
          </div>
        ) : (
          <Empty
            icon={BrainCircuit}
            title="Analytics will appear here"
            body="Connect an approved provider and run the analytics worker to populate live metrics."
          />
        )}
      </section>
      <section className="live-panel">
        <div className="live-panel-head">
          <div>
            <p className="live-kicker">Your library</p>
            <h2>Recent media</h2>
          </div>
          <Button size="sm" onClick={() => setView("media")}>
            <Plus size={14} /> Create media
          </Button>
        </div>
        {assets.length ? (
          assets.slice(0, 4).map((asset) => (
            <button
              type="button"
              className="live-list-row"
              key={asset.id}
              onClick={() => setView("media")}
            >
              <Image size={16} />
              <span>
                <b>{asset.filename}</b>
                <small>
                  {asset.media_type} · {date(asset.created_at)}
                </small>
              </span>
              <Status value={asset.status} />
              <ArrowRight size={15} />
            </button>
          ))
        ) : (
          <Empty
            icon={Image}
            title="Your media library is ready"
            body="Create an image, caption, or video to see it here."
          />
        )}
      </section>
      {streamPreview && (
        <section className="live-panel stream-preview-panel">
          <div className="live-panel-head">
            <div>
              <p className="live-kicker">Live model stream</p>
              <h2>Live writing preview</h2>
            </div>
            <span className="live-helper">SSE connected</span>
          </div>
          <p className="stream-preview-copy">{streamPreview}</p>
        </section>
      )}
      <section className="live-panel overview-quick-start">
        <div className="live-panel-head">
          <div>
            <p className="live-kicker">Next best actions</p>
            <h2>Shape the workspace</h2>
          </div>
          <span className="live-helper">Everything stays reviewable</span>
        </div>
        <div className="overview-actions">
          <button type="button" className="overview-action" onClick={() => setView("media")}>
            <Sparkles size={18} />
            <span>
              <strong>Start creating</strong>
              <small>Generate an image or publish-ready caption from a prompt.</small>
            </span>
            <ArrowRight size={15} />
          </button>
          <button type="button" className="overview-action" onClick={() => setView("publishing")}>
            <Send size={18} />
            <span>
              <strong>{accounts.length ? "Review publishing" : "Connect a channel"}</strong>
              <small>Keep publishing manual until provider approvals are complete.</small>
            </span>
            <ArrowRight size={15} />
          </button>
        </div>
      </section>
    </>
  );
  const campaignsView = (
    <div className="live-columns">
      <section className="live-panel">
        <Reveal3D>
          <p className="live-kicker">New campaign</p>
          <h2>From brief to review</h2>
        </Reveal3D>
        <form className="live-form" onSubmit={createCampaign}>
          <Field label="Campaign name">
            <input
              required
              value={campaignName}
              onChange={(e) => setCampaignName(e.target.value)}
              placeholder="Q4 product launch"
            />
          </Field>
          <Field label="Objective">
            <div className="live-input-with-action">
              <textarea
                required
                value={goal}
                onChange={(e) => setGoal(e.target.value)}
                placeholder="What should this campaign achieve?"
              />
              <VoiceInputButton
                onTranscript={(value) => setGoal((current) => `${current} ${value}`.trim())}
              />
            </div>
          </Field>
          <Field label="Product or service">
            <input
              required
              value={product}
              onChange={(e) => setProduct(e.target.value)}
              placeholder="VAE Studio"
            />
          </Field>
          <Field label="Audience">
            <input
              required
              value={audience}
              onChange={(e) => setAudience(e.target.value)}
              placeholder="Marketing leaders"
            />
          </Field>
          <div className="live-form-grid">
            <fieldset className="live-field platform-picker">
              <legend>Target channels</legend>
              <div className="platform-picker-grid">
                {platforms.map((item) => (
                  <label key={item.id} className="platform-option">
                    <input
                      type="checkbox"
                      checked={selectedPlatforms.includes(item.id)}
                      onChange={() =>
                        setSelectedPlatforms((current) =>
                          current.includes(item.id)
                            ? current.filter((value) => value !== item.id)
                            : [...current, item.id],
                        )
                      }
                    />
                    <span>{item.label}</span>
                  </label>
                ))}
              </div>
            </fieldset>
            <Field label="Instructions">
              <input
                value={instructions}
                onChange={(e) => setInstructions(e.target.value)}
                placeholder="Optional direction"
              />
            </Field>
          </div>
          <Button type="submit" disabled={busy === "campaign"}>
            <Sparkles size={14} /> Create & generate
          </Button>
        </form>
      </section>
      <div className="live-stack">
        <section className="live-panel">
          <p className="live-kicker">Human approval boundary</p>
          <h2>Review queue</h2>
          {campaigns.map((item) => (
            <button
              className={cn("live-list-row", selected === item.id && "selected")}
              key={item.id}
              onClick={() => setSelected(item.id)}
            >
              <Sparkles size={15} />
              <span>
                <b>{item.name}</b>
                <small>{date(item.updated_at)}</small>
              </span>
              <Status value={item.status} />
            </button>
          ))}
        </section>
        <section className="live-panel">
          {currentCampaign ? (
            <>
              <motion.div
                className="live-panel-head"
                layoutId={`campaign-card-${currentCampaign.id}`}
              >
                <div>
                  <p className="live-kicker">Generated variants</p>
                  <h2>{currentCampaign.name}</h2>
                </div>
                <Status value={currentCampaign.status} />
              </motion.div>
              {variants.map((variant) => (
                <article className="live-variant" key={variant.id}>
                  <div>
                    <b>{variant.platform}</b>
                    <span>{Math.round(variant.quality_score)}/100</span>
                  </div>
                  <p>
                    <TypewriterText text={variant.caption} speed={6} />
                  </p>
                  <small>
                    {variant.citations.length} evidence references · {variant.status}
                  </small>
                </article>
              ))}
              {currentCampaign.status === "awaiting_approval" && (
                <div className="live-approval">
                  <Button variant="secondary" onClick={() => void decide("reject")}>
                    Request changes
                  </Button>
                  <Button onClick={() => void decide("approve")}>
                    <Check size={14} /> Approve
                  </Button>
                </div>
              )}
            </>
          ) : (
            <Empty
              icon={ShieldCheck}
              title="Select a campaign"
              body="Inspect variants and approve them before publishing."
            />
          )}
        </section>
      </div>
    </div>
  );
  const brainView = (
    <div className="live-columns">
      <section className="live-panel">
        <Reveal3D>
          <p className="live-kicker">Knowledge base</p>
          <h2>Profile & evidence</h2>
        </Reveal3D>
        {brands[0] ? (
          <div className="live-brand">
            <div>{initial(brands[0].name)}</div>
            <span>
              <b>{brands[0].name}</b>
              <small>{brands[0].description}</small>
            </span>
          </div>
        ) : (
          <form className="live-form" onSubmit={createBrand}>
            <Field label="Brand name">
              <input required value={brandName} onChange={(e) => setBrandName(e.target.value)} />
            </Field>
            <Field label="Description">
              <textarea
                value={brandDescription}
                onChange={(e) => setBrandDescription(e.target.value)}
              />
            </Field>
            <Button type="submit">Create brand profile</Button>
          </form>
        )}
        <div className="live-divider" />
        <form className="live-form" onSubmit={ingest}>
          <Field label="Source title">
            <input
              required
              value={sourceTitle}
              onChange={(e) => setSourceTitle(e.target.value)}
              placeholder="Positioning guide"
            />
          </Field>
          <Field label="Approved source content">
            <textarea
              required
              className="live-tall"
              value={sourceText}
              onChange={(e) => setSourceText(e.target.value)}
              placeholder="Paste verified product evidence…"
            />
          </Field>
          <Button type="submit" disabled={busy === "ingest"}>
            <Upload size={14} /> Index source
          </Button>
        </form>
      </section>
      <div className="live-stack">
        <section className="live-panel">
          <p className="live-kicker">Retrieval preview</p>
          <h2>Ask the Brain</h2>
          <form className="live-search" onSubmit={searchBrain}>
            <input
              required
              minLength={2}
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="What proof supports this claim?"
            />
            <Button size="sm" type="submit">
              Search
            </Button>
          </form>
          {evidence.map((item) => (
            <article className="live-evidence" key={item.chunk_id}>
              <b>{item.document_title}</b>
              <span>{Math.round(item.score * 100)}% match</span>
              <p>
                <TypewriterText text={item.excerpt} speed={8} />
              </p>
            </article>
          ))}
        </section>
        <section className="live-panel">
          <p className="live-kicker">Indexed sources</p>
          <h2>
            {documents.length} source{documents.length === 1 ? "" : "s"}
          </h2>
          {documents.length ? (
            documents.map((doc) => (
              <div className="live-list-row" key={doc.id}>
                <FileText size={15} />
                <span>
                  <b>{doc.title}</b>
                  <small>
                    {doc.source_type} · {doc.content_length.toLocaleString()} chars
                  </small>
                </span>
                <Status value={doc.status} />
              </div>
            ))
          ) : (
            <Empty
              icon={FileText}
              title="Knowledge base is waiting"
              body="Index an approved source to ground generation."
            />
          )}
        </section>
      </div>
    </div>
  );
  const mediaView = (
    <div className="live-columns">
      <section className="live-panel">
        <Reveal3D>
          <p className="live-kicker">Free creator studio</p>
          <h2>Create from a prompt</h2>
        </Reveal3D>
        <div className="live-tabs media-mode-tabs" role="tablist" aria-label="Media type">
          <button
            type="button"
            className={cn(mediaMode === "image" && "active")}
            onClick={() => setMediaMode("image")}
          >
            <Image size={14} /> Image
          </button>
          <button
            type="button"
            className={cn(mediaMode === "text" && "active")}
            onClick={() => setMediaMode("text")}
          >
            <FileText size={14} /> Caption / text
          </button>
        </div>
        <form
          className="live-form"
          onSubmit={
            mediaMode === "image"
              ? createImage
              : (event) => {
                  event.preventDefault();
                  void createText();
                }
          }
        >
          <Field label={mediaMode === "image" ? "Describe the image" : "What should VAE write?"}>
            <textarea
              required
              className="live-tall"
              value={mediaPrompt}
              onChange={(e) => setMediaPrompt(e.target.value)}
              placeholder={
                mediaMode === "image"
                  ? "A cinematic product launch image with warm studio light…"
                  : "Write an Instagram caption for a calm, premium product launch…"
              }
            />
          </Field>
          <p className="live-helper">
            Powered by Groq for text and captions. Images use the free deterministic renderer.
          </p>
          <Button type="submit" disabled={busy === mediaMode}>
            {mediaMode === "image" ? <Sparkles size={14} /> : <FileText size={14} />}
            {busy === mediaMode
              ? "Creating…"
              : mediaMode === "image"
                ? "Generate image"
                : "Generate caption"}
          </Button>
          {generatedText && (
            <div className="generated-copy" aria-live="polite">
              <p>{generatedText}</p>
              <button type="button" onClick={() => setPublishText(generatedText)}>
                Use for publishing <ArrowRight size={12} />
              </button>
            </div>
          )}
          <label className="upload-dropzone">
            <Upload size={16} />
            <span>{uploadingMedia ? "Uploading…" : "Upload an image reference or asset"}</span>
            <small>
              Keep your visual references and finished images together in the private library.
            </small>
            <input
              type="file"
              accept="image/jpeg,image/png,image/webp"
              disabled={uploadingMedia}
              onChange={uploadMedia}
            />
          </label>
        </form>
      </section>
      <section className="live-panel">
        <p className="live-kicker">Asset library</p>
        <h2>
          {assets.length} generated asset{assets.length === 1 ? "" : "s"}
        </h2>
        {assets.length ? (
          assets.map((asset) => (
            <article className="live-asset" key={asset.id}>
              {asset.download_url && asset.media_type === "image" ? (
                // biome-ignore lint/performance/noImgElement: authenticated media is served by the API route.
                <img
                  className="asset-preview"
                  src={asset.download_url}
                  alt={asset.prompt || asset.filename}
                />
              ) : asset.download_url && asset.media_type === "video" ? (
                // biome-ignore lint/a11y/useMediaCaption: generated preview videos are silent compositions.
                <video
                  className="asset-preview"
                  src={asset.download_url}
                  controls
                  preload="metadata"
                />
              ) : null}
              <Image size={22} />
              <Status value={asset.status} />
              <b>{asset.filename}</b>
              <small>
                {asset.media_type} · {date(asset.created_at)}
              </small>
              {asset.download_url && (
                <button type="button" onClick={() => void downloadAsset(asset)}>
                  Open asset <ArrowRight size={12} />
                </button>
              )}
            </article>
          ))
        ) : (
          <Empty
            icon={Image}
            title="Your library is empty"
            body="Describe a visual above or upload your own media."
          />
        )}
      </section>
    </div>
  );
  const publishingView = (
    <div className="live-columns">
      <section className="live-panel">
        <Reveal3D>
          <p className="live-kicker">Channel connector</p>
          <h2>Connect publisher</h2>
        </Reveal3D>
        <p className="live-helper">
          OAuth approval remains required before public publishing; this creates a safely referenced
          account.
        </p>
        <fieldset className="oauth-connect-grid">
          <legend className="sr-only">Secure publisher connections</legend>
          {(["facebook", "instagram", "threads", "youtube", "linkedin"] as const).map(
            (provider) => (
              <button
                type="button"
                className="oauth-connect-button"
                key={provider}
                disabled={busy === `oauth-${provider}`}
                onClick={() => void startOAuth(provider)}
              >
                <span className="oauth-connect-mark">{provider.slice(0, 1).toUpperCase()}</span>
                <span>
                  <strong>{provider === "youtube" ? "YouTube" : provider}</strong>
                  <small>Connect with OAuth</small>
                </span>
                <ArrowRight size={14} />
              </button>
            ),
          )}
        </fieldset>
        <div className="live-divider" />
        <p className="live-helper">
          Connect through the provider consent screen. VAE never asks you to paste a token or
          account ID.
        </p>
        {accounts.map((account) => (
          <div className="live-list-row" key={account.id}>
            <Send size={15} />
            <span>
              <b>{account.display_name}</b>
              <small>
                {account.platform} · {account.capabilities.join(", ")}
              </small>
            </span>
            <Status value={account.status} />
            {account.platform === "linkedin" || account.platform === "youtube" ? (
              <button
                type="button"
                className="icon-button"
                aria-label={`Refresh ${account.display_name}`}
                onClick={() => void refreshAccount(account)}
                disabled={busy === `refresh-${account.id}` || account.status === "revoked"}
              >
                <RefreshCw size={14} />
              </button>
            ) : null}
            <button
              type="button"
              className="icon-button"
              aria-label={`Disconnect ${account.display_name}`}
              onClick={() => void revokeAccount(account)}
              disabled={busy === `revoke-${account.id}` || account.status === "revoked"}
            >
              <X size={14} />
            </button>
          </div>
        ))}
      </section>
      <div className="live-stack">
        <section className="live-panel">
          <p className="live-kicker">Controlled distribution</p>
          <h2>Publish or schedule</h2>
          <div className="live-form">
            <Field label="Campaign">
              <select value={publishCampaign} onChange={(e) => setPublishCampaign(e.target.value)}>
                <option value="">Select campaign</option>
                {campaigns.map((item) => (
                  <option value={item.id} key={item.id}>
                    {item.name}
                  </option>
                ))}
              </select>
            </Field>
            <fieldset className="live-field platform-picker">
              <legend>Publish to connected channels</legend>
              <div className="platform-picker-grid">
                {accounts
                  .filter((item) => item.status === "connected")
                  .map((item) => (
                    <label key={item.id} className="platform-option">
                      <input
                        type="checkbox"
                        checked={publishAccounts.includes(item.id)}
                        onChange={() =>
                          setPublishAccounts((current) =>
                            current.includes(item.id)
                              ? current.filter((value) => value !== item.id)
                              : [...current, item.id],
                          )
                        }
                      />
                      <span>{item.display_name}</span>
                    </label>
                  ))}
              </div>
              {!accounts.some((item) => item.status === "connected") && (
                <small className="live-helper">Connect a channel before publishing.</small>
              )}
            </fieldset>
            <Field label="Post copy">
              <textarea
                value={publishText}
                onChange={(e) => setPublishText(e.target.value)}
                placeholder={currentVariant?.caption || "Choose an approved variant."}
              />
            </Field>
            <Field label={`Schedule time · ${workspace?.timezone ?? "UTC"}`}>
              <input
                type="datetime-local"
                value={scheduleAt}
                onChange={(e) => setScheduleAt(e.target.value)}
              />
            </Field>
            <div className="live-approval">
              <Button variant="secondary" onClick={() => void publish(true)}>
                <CalendarDays size={14} /> Schedule
              </Button>
              <Button onClick={() => void publish(false)}>
                <Send size={14} /> Publish now
              </Button>
            </div>
          </div>
        </section>
        <section className="live-panel">
          <p className="live-kicker">Delivery queue</p>
          <h2>Scheduled posts</h2>
          {scheduled.length ? (
            scheduled.map((item) => (
              <div className="live-list-row" key={item.id}>
                <CalendarDays size={15} />
                <span>
                  <b>{date(item.scheduled_for)}</b>
                  <small>{item.payload.text?.slice(0, 72) || "Campaign post"}</small>
                </span>
                <Status value={item.status} />
                {item.status === "scheduled" || item.status === "failed" ? (
                  <button
                    type="button"
                    className="icon-button"
                    aria-label="Cancel scheduled post"
                    onClick={() => void cancelScheduled(item.id)}
                    disabled={busy === `cancel-${item.id}`}
                  >
                    <X size={14} />
                  </button>
                ) : null}
                {item.status === "scheduled" ? (
                  <button
                    type="button"
                    className="icon-button"
                    aria-label="Reschedule post"
                    onClick={() => void reschedule(item)}
                  >
                    <CalendarDays size={14} />
                  </button>
                ) : null}
                {item.status === "failed" ? (
                  <button
                    type="button"
                    className="icon-button"
                    aria-label="Retry failed post"
                    onClick={() => void retryScheduled(item.id)}
                  >
                    <RefreshCw size={14} />
                  </button>
                ) : null}
              </div>
            ))
          ) : (
            <Empty
              icon={CalendarDays}
              title="No scheduled posts"
              body="Approved content can be scheduled here."
            />
          )}
        </section>
      </div>
    </div>
  );
  const statusCounts = campaigns.reduce(
    (acc, c) => {
      acc[c.status] = (acc[c.status] ?? 0) + 1;
      return acc;
    },
    {} as Record<string, number>,
  );
  const platformCounts = campaigns.reduce(
    (acc, c) => {
      for (const p of c.platforms) acc[p] = (acc[p] ?? 0) + 1;
      return acc;
    },
    {} as Record<string, number>,
  );
  const docTypeCounts = documents.reduce(
    (acc, d) => {
      acc[d.source_type] = (acc[d.source_type] ?? 0) + 1;
      return acc;
    },
    {} as Record<string, number>,
  );
  const assetTypeCounts = assets.reduce(
    (acc, a) => {
      acc[a.media_type] = (acc[a.media_type] ?? 0) + 1;
      return acc;
    },
    {} as Record<string, number>,
  );
  const assetStatusCounts = assets.reduce(
    (acc, a) => {
      acc[a.status] = (acc[a.status] ?? 0) + 1;
      return acc;
    },
    {} as Record<string, number>,
  );
  const approvedCount = campaigns.filter(
    (c) => c.status === "approved" || c.status === "published",
  ).length;
  const approvalRate = campaigns.length ? Math.round((approvedCount / campaigns.length) * 100) : 0;
  const byDay = (rows: Array<{ created_at: string }>) => {
    const map = new Map<string, number>();
    for (const row of rows) {
      const key = new Date(row.created_at).toISOString().slice(0, 10);
      map.set(key, (map.get(key) ?? 0) + 1);
    }
    return [...map.entries()].sort(([a], [b]) => a.localeCompare(b));
  };
  const campaignDays = byDay(campaigns);
  const assetDays = byDay(assets);
  const documentDays = byDay(documents);
  const calendarDays = campaignDays.slice(-28).map(([d, value]) => ({ date: d, value }));
  const variantQuality = variants.map((v) => Math.round(v.quality_score));
  const variantCitations = variants.map((v, i) => ({
    x: v.citations.length,
    y: Math.round(v.quality_score),
    label: `${v.platform}-${i}`,
  }));
  const platformQuality: Record<string, number[]> = {};
  for (const v of variants) {
    const scores = platformQuality[v.platform];
    if (scores) {
      scores.push(v.quality_score);
    } else {
      platformQuality[v.platform] = [v.quality_score];
    }
  }
  const metricTotals = metrics.reduce(
    (totals, item) => ({
      impressions: totals.impressions + item.impressions,
      engagements: totals.engagements + item.engagements,
      likes: totals.likes + item.likes,
      comments: totals.comments + item.comments,
      shares: totals.shares + item.shares,
    }),
    { impressions: 0, engagements: 0, likes: 0, comments: 0, shares: 0 },
  );
  const analyticsView = (
    <div>
      <Reveal3D>
        <p className="live-kicker">Instrument panel</p>
        <h2 style={{ margin: "0 0 16px", fontSize: 21, fontWeight: 500, letterSpacing: "-0.03em" }}>
          Analytics
        </h2>
      </Reveal3D>
      <section className="live-panel analytics-provider-summary">
        <div className="live-panel-head">
          <div>
            <p className="live-kicker">Provider snapshots</p>
            <h2>{metrics.length ? "Live performance" : "Waiting for provider data"}</h2>
          </div>
          <Status value={metrics.length ? "synced" : "manual"} />
        </div>
        <div className="overview-metric-grid">
          <div>
            <strong>{metricTotals.impressions.toLocaleString()}</strong>
            <span>impressions</span>
          </div>
          <div>
            <strong>{metricTotals.engagements.toLocaleString()}</strong>
            <span>engagements</span>
          </div>
          <div>
            <strong>{metricTotals.likes.toLocaleString()}</strong>
            <span>likes</span>
          </div>
          <div>
            <strong>{metricTotals.comments.toLocaleString()}</strong>
            <span>comments</span>
          </div>
          <div>
            <strong>{metricTotals.shares.toLocaleString()}</strong>
            <span>shares</span>
          </div>
        </div>
      </section>
      <div className="analytics-grid">
        <ChartFrame title="Campaign status mix" caption={`${campaigns.length} total`}>
          <DonutChart
            items={Object.entries(statusCounts).map(([label, value]) => ({
              label: label.replaceAll("_", " "),
              value,
            }))}
          />
        </ChartFrame>
        <ChartFrame title="Approval rate" caption="approved + published">
          <GaugeChart value={approvalRate} max={100} label="% approved" />
        </ChartFrame>
        <ChartFrame title="Platform distribution" caption="campaigns by platform">
          <PieChart
            items={Object.entries(platformCounts).map(([label, value]) => ({ label, value }))}
          />
        </ChartFrame>
        <ChartFrame title="Campaigns by platform" caption="ranked">
          <HorizontalBarChart
            items={Object.entries(platformCounts)
              .sort(([, a], [, b]) => b - a)
              .map(([label, value]) => ({ label, value }))}
          />
        </ChartFrame>
        <ChartFrame
          title="Workspace signals"
          caption="sources · campaigns · assets"
          className="span-2"
        >
          <StackedBarChart
            groups={["Sources", "Campaigns", "Assets"]}
            series={[
              { name: "count", values: [documents.length, campaigns.length, assets.length] },
            ]}
          />
        </ChartFrame>
        <ChartFrame title="Campaign creation" caption="daily, real timestamps">
          <AreaChart values={campaignDays.map(([, v]) => v)} />
        </ChartFrame>
        <ChartFrame title="Source ingestion" caption="daily">
          <LineChart values={documentDays.map(([, v]) => v)} />
        </ChartFrame>
        <ChartFrame title="Asset generation" caption="daily">
          <BarChart values={assetDays.map(([, v]) => v)} />
        </ChartFrame>
        <ChartFrame
          title="Activity streams"
          caption="sources / campaigns / assets"
          className="span-2"
        >
          <StreamChart
            series={[
              { name: "Sources", values: documentDays.map(([, v]) => v), color: "#b8bec7" },
              { name: "Campaigns", values: campaignDays.map(([, v]) => v), color: "#c9a45c" },
              { name: "Assets", values: assetDays.map(([, v]) => v), color: "#3f5d52" },
            ]}
          />
        </ChartFrame>
        <ChartFrame title="Recent activity" caption="last 28 campaign days">
          <CalendarHeatmap days={calendarDays} />
        </ChartFrame>
        <ChartFrame title="Approval funnel" caption="status pipeline">
          <FunnelChart
            stages={[
              { label: "Draft", value: statusCounts.draft ?? 0 },
              { label: "Awaiting approval", value: statusCounts.awaiting_approval ?? 0 },
              {
                label: "Approved",
                value: (statusCounts.approved ?? 0) + (statusCounts.published ?? 0),
              },
            ]}
          />
        </ChartFrame>
        <ChartFrame
          title="Variant quality scores"
          caption={`${variants.length} in current campaign`}
        >
          <DotPlot
            items={variants.map((v) => ({ label: v.platform, value: v.quality_score, max: 100 }))}
          />
        </ChartFrame>
        <ChartFrame title="Quality by variant" caption="ranked">
          <LollipopChart
            items={variants.map((v, i) => ({
              label: `${v.platform.slice(0, 3)}${i}`,
              value: Math.round(v.quality_score),
            }))}
          />
        </ChartFrame>
        <ChartFrame title="Quality trend" caption="mini sparkline">
          <Sparkline
            values={variantQuality.length ? variantQuality : [0]}
            width={220}
            height={60}
          />
        </ChartFrame>
        <ChartFrame title="Quality vs. evidence" caption="citations per variant">
          <ScatterChart points={variantCitations} xLabel="citations" yLabel="quality" />
        </ChartFrame>
        <ChartFrame title="Platform quality profile" caption="radar, avg score">
          <RadarChart
            axes={Object.keys(platformQuality)}
            series={[
              {
                name: "avg quality",
                values: Object.values(platformQuality).map(
                  (scores) => scores.reduce((a, b) => a + b, 0) / scores.length,
                ),
              },
            ]}
          />
        </ChartFrame>
        <ChartFrame title="Documents by source type" caption="polar view">
          <PolarAreaChart
            items={Object.entries(docTypeCounts).map(([label, value]) => ({ label, value }))}
          />
        </ChartFrame>
        <ChartFrame title="Asset media mix" caption="images vs video">
          <RadialBarChart
            items={Object.entries(assetTypeCounts).map(([label, value]) => ({
              label,
              value: assets.length ? Math.round((value / assets.length) * 100) : 0,
            }))}
          />
        </ChartFrame>
        <ChartFrame title="Asset pipeline status" caption="generation status">
          <GroupedBarChart
            groups={Object.keys(assetStatusCounts)}
            series={[{ name: "assets", values: Object.values(assetStatusCounts) }]}
          />
        </ChartFrame>
        <ChartFrame title="Content mix by platform" caption="treemap" className="span-2">
          <TreemapChart
            items={Object.entries(platformCounts).map(([label, value]) => ({ label, value }))}
          />
        </ChartFrame>
        <ChartFrame title="Revision range per campaign" caption="derived from revision counters">
          <CandlestickChart
            bars={campaigns.slice(0, 8).map((c) => ({
              label: c.name.slice(0, 6),
              low: 0,
              high: c.current_revision,
              open: 0,
              close: c.current_revision,
            }))}
          />
        </ChartFrame>
        <ChartFrame title="Sources vs. campaigns" caption="waterfall of workspace growth">
          <WaterfallChart
            steps={[
              { label: "Sources", delta: documents.length },
              { label: "Campaigns", delta: campaigns.length },
              { label: "Approved", delta: approvedCount },
              { label: "Assets", delta: assets.length },
            ]}
          />
        </ChartFrame>
        <ChartFrame title="Campaign volume + quality combo" caption="count + latest quality">
          <ComboChart
            bars={campaignDays.map(([, v]) => v)}
            line={campaignDays.map(() => (variantQuality.length ? variantQuality[0] : 0))}
          />
        </ChartFrame>
        <ChartFrame title="Approval completion" caption="ring">
          <ProgressRing value={approvalRate} label="approval rate" />
        </ChartFrame>
        <ChartFrame title="Platform activity" caption="bubble size = campaign count">
          <BubbleChart
            points={Object.entries(platformCounts).map(([label, value], i) => ({
              label,
              x: i,
              y: value,
              size: value,
            }))}
          />
        </ChartFrame>
        <ChartFrame title="Source status heatmap" caption="documents × status">
          <HeatmapChart
            rows={Object.keys(docTypeCounts)}
            cols={["indexed", "pending", "failed"]}
            values={Object.keys(docTypeCounts).map((type) => [
              documents.filter((d) => d.source_type === type && d.status === "indexed").length,
              documents.filter((d) => d.source_type === type && d.status === "pending").length,
              documents.filter((d) => d.source_type === type && d.status === "failed").length,
            ])}
          />
        </ChartFrame>
      </div>
    </div>
  );
  const adminView = (
    <div className="live-columns">
      <section className="live-panel">
        <p className="live-kicker">Administrator</p>
        <h2>Customer operations</h2>
        <p>Monitor non-sensitive customer adoption, media usage, channels, and approvals.</p>
        <div className="admin-kpis">
          <span>
            <b>{adminOverview?.users_total ?? 0}</b> users
          </span>
          <span>
            <b>{adminOverview?.users_approved ?? 0}</b> approved
          </span>
          <span>
            <b>{adminOverview?.assets_total ?? 0}</b> assets
          </span>
          <span>
            <b>{adminOverview?.channels_total ?? 0}</b> channels
          </span>
        </div>
        <Button
          size="sm"
          onClick={() => void loadPaymentSubmissions()}
          disabled={busy === "admin-payments"}
        >
          <RefreshCw size={14} /> Refresh submissions
        </Button>
      </section>
      <section className="live-panel span-2">
        <h2>User usage</h2>
        {adminOverview?.users.length ? (
          adminOverview.users.map((item) => (
            <article className="admin-user-row" key={item.user_id}>
              <span>
                <b>{item.display_name}</b>
                <small>{item.brand_name || item.account_type}</small>
              </span>
              <Status value={item.account_status} />
              <small>{item.assets} assets</small>
              <small>{item.channels} channels</small>
              <small>{item.scheduled} scheduled</small>
              <small>{item.published} published</small>
              <small>{item.engagements} engagements</small>
            </article>
          ))
        ) : (
          <Empty
            icon={UserRound}
            title="No customer activity yet"
            body="Approved customers and usage KPIs will appear here."
          />
        )}
      </section>
      <section className="live-panel">
        <h2>{paymentSubmissions.length} submissions</h2>
        {paymentSubmissions.length ? (
          paymentSubmissions.map((item) => (
            <article className="live-list-row" key={item.id}>
              <ShieldCheck size={16} />
              <span>
                <b>{item.display_name}</b>
                <small>
                  {item.email} · {item.utr_reference || "No UTR"}
                </small>
              </span>
              <Status value={item.status} />
              {item.status !== "approved" && item.status !== "rejected" ? (
                <span className="live-inline-actions">
                  <Button size="sm" onClick={() => void reviewPayment(item, "approve")}>
                    Approve
                  </Button>
                  <Button
                    size="sm"
                    variant="ghost"
                    onClick={() => void reviewPayment(item, "reject")}
                  >
                    Reject
                  </Button>
                </span>
              ) : null}
            </article>
          ))
        ) : (
          <Empty
            icon={ShieldCheck}
            title="No payment submissions"
            body="Refresh when a tenant submits UPI proof."
          />
        )}
      </section>
    </div>
  );
  const content =
    view === "overview"
      ? overview
      : view === "campaigns"
        ? campaignsView
        : view === "brain"
          ? brainView
          : view === "media"
            ? mediaView
            : view === "analytics"
              ? analyticsView
              : view === "admin"
                ? adminView
                : publishingView;
  const paletteItems = [
    ...nav.map((item) => ({
      label: `Open ${item.label}`,
      hint: "View",
      onSelect: () => setView(item.id),
    })),
    { label: "Create media", hint: "Create", onSelect: () => setView("media") },
    {
      label: theme === "dark" ? "Use light theme" : "Use dark theme",
      hint: "Appearance",
      onSelect: toggleTheme,
    },
    {
      label: soundEnabled ? "Mute ambient sound" : "Enable ambient sound",
      hint: "Audio",
      onSelect: () => setSoundEnabled(!soundEnabled),
    },
  ];
  return (
    <MotionConfig reducedMotion="user">
      <main className={cn("live-app", `view-${view}`)} data-theme={theme}>
        <WebglBackground />
        <GrainOverlay />
        {themeWipe && <div className={`theme-wipe ${themeWipe}`} aria-hidden="true" />}
        {paletteOpen && (
          <CommandPalette items={paletteItems} onClose={() => setPaletteOpen(false)} />
        )}
        {tourOpen && (
          <Onboarding
            onDismiss={() => {
              window.localStorage.setItem("vae.tour-complete", "1");
              setTourOpen(false);
            }}
            onComplete={() => {
              window.localStorage.setItem("vae.tour-complete", "1");
              setTourOpen(false);
            }}
          />
        )}
        <AnimatePresence>
          {signOutOpen && (
            <motion.div
              className="confirm-layer"
              role="presentation"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onMouseDown={() => !signingOut && setSignOutOpen(false)}
            >
              <motion.div
                className="confirm-dialog"
                role="dialog"
                aria-modal="true"
                aria-labelledby="sign-out-title"
                initial={{ opacity: 0, y: 16, scale: 0.97 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: 10, scale: 0.98 }}
                transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
                onMouseDown={(event) => event.stopPropagation()}
              >
                <button
                  className="confirm-close"
                  type="button"
                  aria-label="Close sign out dialog"
                  disabled={signingOut}
                  onClick={() => setSignOutOpen(false)}
                >
                  <X size={16} />
                </button>
                <p className="live-kicker">Account</p>
                <h2 id="sign-out-title">Sign out of VAE?</h2>
                <p>Your account is safe. You can return and sign in again at any time.</p>
                <div className="confirm-actions">
                  <Button
                    type="button"
                    variant="ghost"
                    disabled={signingOut}
                    onClick={() => setSignOutOpen(false)}
                  >
                    Cancel
                  </Button>
                  <Button
                    type="button"
                    disabled={signingOut}
                    onClick={async () => {
                      setSigningOut(true);
                      try {
                        await api.logout();
                      } finally {
                        reset();
                        setSigningOut(false);
                        setSignOutOpen(false);
                      }
                    }}
                  >
                    <LogOut size={15} /> {signingOut ? "Signing out…" : "Sign out"}
                  </Button>
                </div>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
        <AnimatePresence>
          {profileOpen && user && (
            <motion.div
              className="confirm-layer"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onMouseDown={() => setProfileOpen(false)}
            >
              <motion.form
                className="confirm-dialog profile-dialog"
                onSubmit={saveProfile}
                initial={{ opacity: 0, y: 16, scale: 0.97 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: 10, scale: 0.98 }}
                onMouseDown={(event) => event.stopPropagation()}
              >
                <button
                  className="confirm-close"
                  type="button"
                  onClick={() => setProfileOpen(false)}
                >
                  <X size={16} />
                </button>
                <p className="live-kicker">Profile</p>
                <h2>Edit your account</h2>
                <div className="profile-avatar-preview">
                  {profileAvatar ? (
                    // biome-ignore lint/performance/noImgElement: user-provided remote avatar URLs are not known at build time.
                    <img src={profileAvatar} alt="Profile preview" />
                  ) : (
                    <UserRound size={24} />
                  )}
                </div>
                <Field label="Display name">
                  <input
                    required
                    value={profileName}
                    onChange={(e) => setProfileName(e.target.value)}
                  />
                </Field>
                <Field label="Email">
                  <input
                    required
                    type="email"
                    value={profileEmail}
                    onChange={(e) => setProfileEmail(e.target.value)}
                  />
                </Field>
                <Field label="Product or brand">
                  <input value={profileBrand} onChange={(e) => setProfileBrand(e.target.value)} />
                </Field>
                <Field label="Profile photo URL">
                  <input
                    type="url"
                    value={profileAvatar}
                    onChange={(e) => setProfileAvatar(e.target.value)}
                    placeholder="https://…"
                  />
                </Field>
                <div className="live-divider" />
                <Field label="Current password (only to change it)">
                  <input
                    type="password"
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                  />
                </Field>
                <Field label="New password">
                  <input
                    type="password"
                    minLength={8}
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                  />
                </Field>
                <Button type="submit" className="live-full-button" disabled={busy === "profile"}>
                  {busy === "profile" ? "Saving…" : "Save profile"}
                </Button>
              </motion.form>
            </motion.div>
          )}
        </AnimatePresence>
        <aside className={cn("live-sidebar", sidebar && "open")}>
          <div className="live-logo">
            <span />
            <b>VAE</b>
            <button onClick={() => setSidebar(false)} aria-label="Close">
              <X size={17} />
            </button>
          </div>
          <div className="live-workspace">
            <div>{initial(user?.brand_name || user?.display_name)}</div>
            <span>
              <b>{user?.brand_name || user?.display_name}</b>
              <small>{user?.account_type === "business" ? "Business" : "Creator"}</small>
            </span>
          </div>
          <nav>
            {nav.map((item) => (
              <button
                className={cn(view === item.id && "active")}
                key={item.id}
                onClick={() => {
                  setView(item.id);
                  if (item.id === "admin") void loadPaymentSubmissions();
                  setSidebar(false);
                }}
              >
                <item.icon size={17} />
                <span>{item.label}</span>
              </button>
            ))}
          </nav>
          <div className="live-sidebar-foot">
            <button className="live-user profile-trigger" onClick={() => setProfileOpen(true)}>
              <div>
                {user?.avatar_url ? (
                  // biome-ignore lint/performance/noImgElement: user-provided remote avatar URLs are dynamic.
                  <img src={user.avatar_url} alt="" />
                ) : (
                  initial(user?.display_name)
                )}
              </div>
              <span>
                <b>{user?.display_name}</b>
                <small>{user?.email}</small>
              </span>
            </button>
            <button onClick={() => setSignOutOpen(true)}>
              <LogOut size={15} /> Sign out
            </button>
          </div>
        </aside>
        {sidebar && (
          <button
            className="live-backdrop"
            onClick={() => setSidebar(false)}
            aria-label="Close navigation"
          />
        )}
        <section className="live-main" data-scrolled={scrolled}>
          <header className="live-topbar">
            <button onClick={() => setSidebar(true)} aria-label="Open navigation">
              <Menu size={19} />
            </button>
            <span>
              <i /> VAE online
            </span>
            <div>
              <button className="live-command-trigger" onClick={() => setPaletteOpen(true)}>
                <Search size={14} /> <span>Search</span> <kbd>⌘K</kbd>
              </button>
              <SoundToggle enabled={soundEnabled} onChange={setSoundEnabled} />
              <button className="live-theme-toggle" onClick={toggleTheme}>
                {theme === "dark" ? "Light" : "Dark"}
              </button>
              <button className="live-refresh" onClick={() => token && void load(token)}>
                <RefreshCw size={15} /> Refresh
              </button>
              <Button size="sm" onClick={() => setView("media")}>
                <Plus size={14} /> Create media
              </Button>
            </div>
          </header>
          <div
            ref={contentRef}
            className="live-content"
            style={{ "--glass-alpha": scrolled ? 0.82 : 0.62 } as CSSProperties}
          >
            <AnimatePresence>
              {notice && (
                <motion.div
                  className="live-alert success"
                  variants={overlayFade}
                  initial="hidden"
                  animate="show"
                  exit="exit"
                >
                  <Check size={15} /> <TypewriterText text={notice} speed={14} />
                  <button onClick={() => setNotice(null)}>
                    <X size={14} />
                  </button>
                </motion.div>
              )}
              {error && (
                <motion.div
                  className="live-alert error"
                  variants={overlayFade}
                  initial="hidden"
                  animate="show"
                  exit="exit"
                >
                  <CircleAlert size={15} /> {error}
                  <button onClick={() => setError(null)}>
                    <X size={14} />
                  </button>
                </motion.div>
              )}
            </AnimatePresence>
            {busy === "load" ? (
              <div className="live-stats">
                {[0, 1, 2, 3].map((i) => (
                  <article key={i}>
                    <div className="live-skeleton" style={{ width: 18, height: 18 }} />
                    <div className="live-skeleton" style={{ width: "60%", height: 10 }} />
                    <div className="live-skeleton" style={{ width: "40%", height: 26 }} />
                    <div className="live-skeleton" style={{ width: "70%", height: 9 }} />
                  </article>
                ))}
              </div>
            ) : (
              <AnimatePresence mode="wait">
                <motion.div
                  key={view}
                  className={view === "overview" ? "overview-layout" : "view-layout"}
                  variants={variantSwap}
                  initial="hidden"
                  animate="show"
                  exit="exit"
                >
                  {content}
                </motion.div>
              </AnimatePresence>
            )}
          </div>
        </section>
      </main>
    </MotionConfig>
  );
}
