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
  Moon,
  Plus,
  RefreshCw,
  Search,
  Send,
  ShieldCheck,
  Sparkles,
  Sun,
  Upload,
  UserRound,
  X,
} from "lucide-react";
import { AnimatePresence, MotionConfig, motion } from "motion/react";
import dynamic from "next/dynamic";
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
import { flushSync } from "react-dom";
import { AdminDashboard, type AdminSection } from "@/components/admin-dashboard";
import {
  AiOrb,
  CommandPalette,
  DepthCard,
  Onboarding,
  ParticleField,
  Reveal,
  SoundToggle,
  TypewriterText,
  VoiceInputButton,
} from "@/components/advanced-ui";
import { GrainOverlay } from "@/components/background/grain-overlay";
import { HeroVideo } from "@/components/background/hero-video";
import { WebglBackground } from "@/components/background/webgl-background";
import { CaptionEditor } from "@/components/caption-editor";
import { LandingStory } from "@/components/landing-story";
import { MlStudio } from "@/components/ml-studio";
import { PublishingCalendar } from "@/components/publishing-calendar";

const AreaChart = dynamic(() => import("@/components/charts").then((m) => m.AreaChart));
const BarChart = dynamic(() => import("@/components/charts").then((m) => m.BarChart));
const BubbleChart = dynamic(() => import("@/components/charts").then((m) => m.BubbleChart));
const CalendarHeatmap = dynamic(() => import("@/components/charts").then((m) => m.CalendarHeatmap));
const CandlestickChart = dynamic(() =>
  import("@/components/charts").then((m) => m.CandlestickChart),
);
const ChartFrame = dynamic(() => import("@/components/charts").then((m) => m.ChartFrame));
const ComboChart = dynamic(() => import("@/components/charts").then((m) => m.ComboChart));
const DonutChart = dynamic(() => import("@/components/charts").then((m) => m.DonutChart));
const DotPlot = dynamic(() => import("@/components/charts").then((m) => m.DotPlot));
const FunnelChart = dynamic(() => import("@/components/charts").then((m) => m.FunnelChart));
const GaugeChart = dynamic(() => import("@/components/charts").then((m) => m.GaugeChart));
const GroupedBarChart = dynamic(() => import("@/components/charts").then((m) => m.GroupedBarChart));
const HeatmapChart = dynamic(() => import("@/components/charts").then((m) => m.HeatmapChart));
const HorizontalBarChart = dynamic(() =>
  import("@/components/charts").then((m) => m.HorizontalBarChart),
);
const LineChart = dynamic(() => import("@/components/charts").then((m) => m.LineChart));
const LollipopChart = dynamic(() => import("@/components/charts").then((m) => m.LollipopChart));
const PieChart = dynamic(() => import("@/components/charts").then((m) => m.PieChart));
const PolarAreaChart = dynamic(() => import("@/components/charts").then((m) => m.PolarAreaChart));
const ProgressRing = dynamic(() => import("@/components/charts").then((m) => m.ProgressRing));
const RadarChart = dynamic(() => import("@/components/charts").then((m) => m.RadarChart));
const RadialBarChart = dynamic(() => import("@/components/charts").then((m) => m.RadialBarChart));
const ScatterChart = dynamic(() => import("@/components/charts").then((m) => m.ScatterChart));
const Sparkline = dynamic(() => import("@/components/charts").then((m) => m.Sparkline));
const StackedBarChart = dynamic(() => import("@/components/charts").then((m) => m.StackedBarChart));
const StreamChart = dynamic(() => import("@/components/charts").then((m) => m.StreamChart));
const TreemapChart = dynamic(() => import("@/components/charts").then((m) => m.TreemapChart));
const WaterfallChart = dynamic(() => import("@/components/charts").then((m) => m.WaterfallChart));

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

type View =
  | "overview"
  | "campaigns"
  | "brain"
  | "media"
  | "publishing"
  | "analytics"
  | "admin"
  | "ml";
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

export function LiveWorkspace({ adminPortal = false }: { adminPortal?: boolean }) {
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
  const [previewAsset, setPreviewAsset] = useState<MediaAsset | null>(null);
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
  const [profileAvatarBusy, setProfileAvatarBusy] = useState(false);
  const avatarInputRef = useRef<HTMLInputElement>(null);
  const prefetchedSessionUser = useRef<User | null>(null);
  const authCardRef = useRef<HTMLFormElement>(null);
  const focusAuthCard = useCallback((nextMode?: "login" | "register") => {
    if (nextMode) setMode(nextMode);
    authCardRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
    window.setTimeout(() => {
      authCardRef.current?.querySelector<HTMLInputElement>("input")?.focus();
    }, 260);
  }, []);
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
  const [aspectRatio, setAspectRatio] = useState("1:1");
  const [generationPhase, setGenerationPhase] = useState("");
  const [outputCount, setOutputCount] = useState(1);
  const [assetLimit, setAssetLimit] = useState(12);
  const [analyticsChannel, setAnalyticsChannel] = useState("");
  const [analyticsDays, setAnalyticsDays] = useState(30);
  const [publishReview, setPublishReview] = useState<boolean | null>(null);
  const [mediaMode, setMediaMode] = useState<"image" | "text">("image");
  const [generatedText, setGeneratedText] = useState("");
  const [captionAsset, setCaptionAsset] = useState<MediaAsset | null>(null);
  const [assetCaption, setAssetCaption] = useState("");
  const [extraAssetIds, setExtraAssetIds] = useState<string[]>([]);
  const [uploadingMedia, setUploadingMedia] = useState(false);
  const [publishAssetId, setPublishAssetId] = useState("");
  const [publishAccounts, setPublishAccounts] = useState<string[]>([]);
  const [delivery, setDelivery] = useState<Record<string, string>>({});
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
  const [paymentsLoaded, setPaymentsLoaded] = useState(false);
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
  const themeTransition = useRef(false);
  const submissionKeys = useRef(new Map<string, string>());
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
  useEffect(() => {
    if (
      !(
        profileOpen ||
        captionAsset ||
        previewAsset ||
        signOutOpen ||
        paletteOpen ||
        tourOpen ||
        publishReview !== null
      )
    )
      return;
    const previous = document.activeElement as HTMLElement | null;
    const previousOverflow = document.body.style.overflow;
    const previousRootOverflow = document.documentElement.style.overflow;
    document.body.style.overflow = "hidden";
    document.documentElement.style.overflow = "hidden";
    const background = Array.from(
      document.querySelectorAll<HTMLElement>(".live-sidebar, .live-main, .creator-bottom-nav"),
    );
    const previousInert = background.map((element) => element.inert);
    background.forEach((element) => {
      element.inert = true;
    });
    const dialog = document.querySelector<HTMLElement>(
      '[role="dialog"], .command-dialog, .onboarding-card',
    );
    const focusable = () =>
      Array.from(
        dialog?.querySelectorAll<HTMLElement>(
          'button:not([disabled]), a[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex="0"]',
        ) ?? [],
      );
    focusable()[0]?.focus();
    const keyboard = (event: KeyboardEvent) => {
      if (event.key === "Escape" && !signingOut) {
        setProfileOpen(false);
        setPreviewAsset(null);
        setCaptionAsset(null);
        setSignOutOpen(false);
        setPaletteOpen(false);
        setPublishReview(null);
      }
      if (event.key !== "Tab") return;
      const nodes = focusable();
      const first = nodes[0];
      const last = nodes[nodes.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last?.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first?.focus();
      }
    };
    document.addEventListener("keydown", keyboard);
    return () => {
      document.body.style.overflow = previousOverflow;
      document.documentElement.style.overflow = previousRootOverflow;
      background.forEach((element, index) => {
        element.inert = previousInert[index];
      });
      document.removeEventListener("keydown", keyboard);
      previous?.focus();
    };
  }, [
    profileOpen,
    captionAsset,
    previewAsset,
    signOutOpen,
    paletteOpen,
    tourOpen,
    publishReview,
    signingOut,
  ]);
  const currentCampaign = campaigns.find((item) => item.id === selected);
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
    if (themeTransition.current) return;
    const next = theme === "dark" ? "light" : "dark";
    const applyTheme = () => {
      document.documentElement.dataset.theme = next;
      flushSync(() => setTheme(next));
    };
    if (
      !document.startViewTransition ||
      window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ) {
      applyTheme();
      return;
    }
    themeTransition.current = true;
    document.documentElement.classList.add("theme-transition");
    const transition = document.startViewTransition(applyTheme);
    void transition.finished
      .catch(() => {})
      .finally(() => {
        themeTransition.current = false;
        document.documentElement.classList.remove("theme-transition");
      });
  }, [theme]);
  const reset = useCallback(() => {
    setAdminOverview(null);
    setPaymentSubmissions([]);
    setPaymentsLoaded(false);
    setView("overview");
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
        // Identity and workspace membership are independent requests. Starting
        // them together removes a full network round-trip from sign-in,
        // especially noticeable when the API is waking from an idle deploy.
        const cachedUser = prefetchedSessionUser.current;
        prefetchedSessionUser.current = null;
        const [me, workspaces] = await Promise.all([
          cachedUser ? Promise.resolve(cachedUser) : api.me(accessToken),
          api.workspaces(accessToken),
        ]);
        if (me.is_admin !== adminPortal) {
          window.location.replace(me.is_admin ? "/admin" : "/");
          return;
        }
        setUser(me);
        if (me.is_admin) {
          setWorkspace(workspaces[0] ?? null);
          setBusy(null);
          void api
            .adminOverview(accessToken)
            .then(setAdminOverview)
            .catch((caught) =>
              setError(caught instanceof Error ? caught.message : "Unable to load admin report."),
            );
          return;
        }
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
        setBrands(nextBrands);
        setCampaigns(nextCampaigns);
        setDocuments(nextDocuments);
        setAssets(nextAssets);
        setAccounts(nextAccounts);
        setScheduled(nextScheduled);
        setMetrics(nextMetrics);
        setSelected((value) => value || nextCampaigns[0]?.id || "");
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
    [reset, adminPortal],
  );
  useEffect(() => {
    window.localStorage.removeItem(legacyTokenKey);
    api
      .me(browserSession)
      .then((me) => {
        prefetchedSessionUser.current = me;
        setToken(browserSession);
      })
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
    setTourOpen(!adminPortal && window.localStorage.getItem("vae.tour-complete") !== "1");
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
  }, [adminPortal]);
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
          ? await api.login(email, password, adminPortal)
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
      const payments = await api.adminPayments(token);
      setPaymentSubmissions(payments);
      setPaymentsLoaded(true);
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
  const uploadProfileAvatar = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file || !token || !user) return;
    if (!workspace) {
      setError("A workspace is required to upload a profile picture.");
      return;
    }
    setProfileAvatarBusy(true);
    try {
      if (!file.type.startsWith("image/")) throw new Error("Choose an image file.");
      const uploaded = await api.uploadMedia(token, workspace.id, null, file);
      if (!uploaded.download_url) throw new Error("The avatar upload did not return a preview.");
      setProfileAvatar(uploaded.download_url);
      const updated = await api.updateProfile(token, {
        display_name: profileName || user.display_name,
        email: profileEmail || user.email,
        account_type: user.account_type,
        brand_name: profileBrand || null,
        avatar_url: uploaded.download_url,
      });
      setUser(updated);
      setNotice("Profile picture updated.");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Profile image upload failed.");
    } finally {
      setProfileAvatarBusy(false);
      event.target.value = "";
    }
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
      setGenerationPhase("Preparing your creative brief…");
      const enhancedPrompt = await api
        .streamModel(
          token,
          workspace.id,
          {
            prompt: mediaPrompt,
            system_prompt:
              "Rewrite the user's request as a vivid, safe image-generation brief. Preserve named characters and actions, add composition, lighting, palette, camera, and mood. Return only the brief.",
            max_tokens: 320,
          },
          () => undefined,
        )
        .catch(() => mediaPrompt);
      for (let output = 0; output < outputCount; output++) {
        setGenerationPhase(`Generating image ${output + 1} of ${outputCount}…`);
        const result = await api.generateImage(token, workspace.id, {
          campaign_id: null,
          prompt: enhancedPrompt,
          name_prompt: mediaPrompt,
          platforms: ["instagram"],
          aspect_ratio: aspectRatio,
          brand_overlay: true,
          brand_text: brands[0]?.name ?? "VAE",
        });
        setAssets((items) => [...result.assets, ...items]);
        if (output === 0 && result.assets[0]) {
          setCaptionAsset(result.assets[0]);
          setAssetCaption(generatedText || publishText);
        }
      }
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
    if (!token || !workspace) return;
    if (!publishAccounts.length || !publishText.trim()) {
      setError("Select a connected channel and write or generate a caption.");
      return;
    }
    if (shouldSchedule && (!scheduleAt || new Date(scheduleAt).getTime() <= Date.now())) {
      setError("Choose a future date and time.");
      return;
    }
    setPublishReview(null);
    setDelivery({});
    await run(shouldSchedule ? "schedule" : "publish", async () => {
      const selectedIds = [...new Set([publishAssetId, ...extraAssetIds].filter(Boolean))];
      const batch = selectedIds.length ? selectedIds : [""];
      const results = await Promise.all(
        publishAccounts.flatMap((accountId) =>
          batch.map(async (assetId) => {
            const asset = assets.find((item) => item.id === assetId);
            const deliveryId = `${accountId}:${assetId}`;
            try {
              const fingerprint = JSON.stringify([
                workspace.id,
                accountId,
                assetId,
                publishText,
                shouldSchedule ? scheduleAt : "now",
              ]);
              const submissionKey = submissionKeys.current.get(fingerprint) ?? idempotency();
              submissionKeys.current.set(fingerprint, submissionKey);
              const payload = {
                campaign_id: null,
                social_account_id: accountId,
                idempotency_key: submissionKey,
                text: publishText,
                media_urls: asset?.download_url ? [asset.download_url] : [],
              };
              const result = shouldSchedule
                ? await api.schedule(token, workspace.id, {
                    ...payload,
                    scheduled_for: new Date(scheduleAt).toISOString(),
                  })
                : await api.publish(token, workspace.id, payload);
              setDelivery((current) => ({ ...current, [deliveryId]: result.status }));
              if (shouldSchedule)
                setScheduled((current) => [
                  result as ScheduledPost,
                  ...current.filter((p) => p.id !== result.id),
                ]);
              return result.status !== "failed";
            } catch (reason) {
              setDelivery((current) => ({
                ...current,
                [deliveryId]:
                  reason instanceof Error ? `Failed: ${reason.message}` : "Failed. Try again.",
              }));
              return false;
            }
          }),
        ),
      );
      const succeeded = results.filter(Boolean).length;
      setNotice(
        `${succeeded} of ${results.length} posts ${shouldSchedule ? "scheduled" : "submitted"}. See delivery status below.`,
      );
    });
  };
  const uploadPublishAsset = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = "";
    if (!file || !token || !workspace) return;
    if ([publishAssetId, ...extraAssetIds].filter(Boolean).length >= 4) {
      setError("Select up to four assets per batch.");
      return;
    }
    setUploadingMedia(true);
    try {
      const asset = await api.uploadMedia(token, workspace.id, null, file);
      setAssets((items) => [asset, ...items]);
      if (publishAssetId) setExtraAssetIds((ids) => [...ids, asset.id]);
      else setPublishAssetId(asset.id);
      setNotice("Asset uploaded and added to your publishing batch.");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Asset upload failed.");
    } finally {
      setUploadingMedia(false);
    }
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
        <main className={cn("live-auth", adminPortal && "admin-auth")}>
          <WebglBackground variant={adminPortal ? "admin" : "creator"} />
          <HeroVideo />
          <div className="hero-video-overlay" aria-hidden="true" />
          <GrainOverlay />
          <header className="landing-nav">
            <div className="live-logo brand-lockup">
              {/* biome-ignore lint/performance/noImgElement: static brand SVG */}
              <img src="/brand/vae-admin-icon.svg" alt="" />
              <span className="brand-wordmark" role="img" aria-label="VAE">
                <b>V</b>
                <em>AE</em>
              </span>
            </div>
            <div className="landing-nav-links">
              <button
                type="button"
                className="landing-nav-cta"
                onClick={toggleTheme}
                aria-label={theme === "dark" ? "Switch to light theme" : "Switch to dark theme"}
              >
                {theme === "dark" ? <Sun size={16} /> : <Moon size={16} />}
                <span className="nav-label">{theme === "dark" ? "Light" : "Dark"}</span>
              </button>
              {!adminPortal && (
                <button
                  type="button"
                  className="landing-nav-cta"
                  onClick={() => focusAuthCard("login")}
                >
                  <span className="nav-long">Creator / Business sign in</span>
                  <span className="nav-short">Sign in</span>
                </button>
              )}
              <button
                type="button"
                className="landing-nav-cta primary"
                onClick={() => focusAuthCard(adminPortal ? undefined : "register")}
              >
                <span className="nav-long">
                  {adminPortal ? "Administrator sign in" : "Get started"}
                </span>
                <span className="nav-short">{adminPortal ? "Sign in" : "Get started"}</span>
              </button>
              <a className="landing-nav-cta nav-secondary" href={adminPortal ? "/" : "/admin"}>
                <ShieldCheck size={14} />
                <span>{adminPortal ? "Creator sign in" : "Admin sign in"}</span>
              </a>
            </div>
          </header>
          <motion.section
            className="landing-hero-copy"
            initial={{ opacity: 0, y: 16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
          >
            <p className="live-kicker">
              {adminPortal ? "VAE administration" : "Your creative workspace"}
            </p>
            <h1>
              {adminPortal ? "A clear view of your operations." : "Your ideas. Beautifully made."}
            </h1>
            <p>
              {adminPortal
                ? "Monitor customer adoption, generation usage, publishing health, and payment approvals."
                : "A quiet space to create media, connect your channels, and share what matters."}
            </p>
            <div className="live-auth-points">
              <span>
                <Check size={15} /> {adminPortal ? "Customer KPIs." : "Create media."}
              </span>
              <span>
                <Check size={15} /> {adminPortal ? "Usage insights." : "Connect channels."}
              </span>
              <span>
                <Check size={15} /> {adminPortal ? "Payment review." : "Publish on schedule."}
              </span>
            </div>
            <section className="landing-proof" aria-label="Platform highlights">
              <span>
                <strong>One workspace</strong>
                <small>
                  {adminPortal ? "Complete operational control" : "From idea to published post"}
                </small>
              </span>
              <span>
                <strong>{adminPortal ? "Live clarity" : "AI, refined"}</strong>
                <small>
                  {adminPortal
                    ? "Signals that support decisions"
                    : "Creative control stays with you"}
                </small>
              </span>
            </section>
          </motion.section>
          <motion.form
            ref={authCardRef}
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
                          <div role="alert" className="live-alert error">
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
                {!adminPortal && (
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
                      Creator / Business sign up
                    </button>
                  </div>
                )}
                <h2>
                  {adminPortal
                    ? "Administrator sign in"
                    : mode === "login"
                      ? "Welcome back"
                      : "Create your VAE account"}
                </h2>
                <p>
                  {adminPortal
                    ? "Access customer operations and payment review with your administrator account."
                    : mode === "login"
                      ? "Your creator workspace starts here."
                      : "Choose Creator or Business below to set up your workspace."}
                </p>
                {notice && mode === "login" && (
                  <div role="status" className="live-alert success">
                    <Check size={15} /> {notice}
                  </div>
                )}
                {error && (
                  <div role="alert" className="live-alert error">
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
                    <div className="live-field">
                      <span>Account type</span>
                      <div
                        className="account-type-picker"
                        role="radiogroup"
                        aria-label="Account type"
                      >
                        {/* biome-ignore lint/a11y/useSemanticElements: card-style selector preserves button keyboard behavior inside the form. */}
                        <button
                          type="button"
                          role="radio"
                          aria-checked={accountType === "creator"}
                          className={cn(
                            "account-type-option",
                            accountType === "creator" && "active",
                          )}
                          onClick={() => setAccountType("creator")}
                        >
                          <strong>Creator</strong>
                          <small>Publish under your own name and voice.</small>
                        </button>
                        {/* biome-ignore lint/a11y/useSemanticElements: card-style selector preserves button keyboard behavior inside the form. */}
                        <button
                          type="button"
                          role="radio"
                          aria-checked={accountType === "business"}
                          className={cn(
                            "account-type-option",
                            accountType === "business" && "active",
                          )}
                          onClick={() => setAccountType("business")}
                        >
                          <strong>Business</strong>
                          <small>Publish for a brand or team workspace.</small>
                        </button>
                      </div>
                    </div>
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
                  {busy === "auth"
                    ? "Signing in…"
                    : adminPortal
                      ? "Sign in as administrator"
                      : mode === "login"
                        ? "Sign in"
                        : "Get started"}
                </Button>
                <a className="login-portal-link" href={adminPortal ? "/" : "/admin"}>
                  {adminPortal ? "Creator sign in" : "Administrator sign in"}
                </a>
              </>
            )}
            {onboarding && error && (
              <div role="alert" className="live-alert error">
                <CircleAlert size={15} /> {error}
              </div>
            )}
          </motion.form>
          <LandingStory audience={adminPortal ? "admin" : "creator"} />
        </main>
      </MotionConfig>
    );
  if (!user)
    return (
      <main className={cn("live-auth", adminPortal && "admin-auth")}>
        <section role="status">
          <h1>Loading your workspace</h1>
          {error ? (
            <>
              <p>{error}</p>
              <Button onClick={() => void load(token)}>Retry</Button>
              <a href={adminPortal ? "/admin" : "/"}>Back to sign in</a>
            </>
          ) : (
            <p>Checking your account access…</p>
          )}
        </section>
      </main>
    );
  const nav = user?.is_admin
    ? [
        { id: "overview" as View, label: "Home", icon: BrainCircuit },
        { id: "media" as View, label: "AI usage", icon: Sparkles },
        { id: "publishing" as View, label: "Publishing", icon: CalendarDays },
        { id: "analytics" as View, label: "Analytics", icon: BrainCircuit },
        { id: "admin" as View, label: "Payment review", icon: ShieldCheck },
      ]
    : [
        { id: "overview" as View, label: "Home", icon: BrainCircuit },
        { id: "media" as View, label: "Create", icon: Sparkles },
        { id: "publishing" as View, label: "Publish", icon: CalendarDays },
        { id: "analytics" as View, label: "Analytics", icon: BrainCircuit },
        { id: "ml" as View, label: "ML insights", icon: Sparkles },
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

          <Button onClick={() => setView("media")}>
            Create media <Plus size={14} />
          </Button>
        </div>
      </Reveal>
      <Reveal className="live-stats bento-grid">
        {metricOrder.map((metric) => {
          const metricData = {
            assets: [Image, "Media assets", assets.length, "in your library"],
            channels: [
              Send,
              "Connected channels",
              accounts.filter((a) => a.status === "connected").length,
              "ready to publish",
            ],
            scheduled: [
              CalendarDays,
              "Scheduled",
              scheduled.filter((p) => p.status === "scheduled").length,
              "upcoming posts",
            ],
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
          <h2>Coming up next</h2>
          <Button variant="secondary" onClick={() => setView("publishing")}>
            Publish
          </Button>
        </div>
        {scheduled.length ? (
          scheduled.slice(0, 4).map((post) => (
            <div className="live-list-row" key={post.id}>
              <CalendarDays size={18} />
              <span>
                <b>{date(post.scheduled_for)}</b>
                <small>{post.payload.text || "Media post"}</small>
              </span>
              <Status value={post.status} />
            </div>
          ))
        ) : (
          <Empty
            icon={CalendarDays}
            title="Make room for your next idea"
            body="Choose an asset and schedule your first post."
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
              <small>Choose an asset, write a caption, and pick the right moment.</small>
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
          <p className="live-kicker">Creator studio</p>
          <h2>Create from a prompt</h2>
        </Reveal3D>
        <fieldset className="live-tabs media-mode-tabs" aria-label="Media type">
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
        </fieldset>
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
            Describe the subject, light, and mood. Your draft stays here as you explore.
          </p>
          {mediaMode === "image" && (
            <div className="composer-options">
              <Field label="Aspect ratio">
                <select value={aspectRatio} onChange={(e) => setAspectRatio(e.target.value)}>
                  <option>1:1</option>
                  <option>4:5</option>
                  <option>9:16</option>
                  <option>16:9</option>
                </select>
              </Field>
              <Field label="Outputs">
                <select
                  value={outputCount}
                  onChange={(e) => setOutputCount(Number(e.target.value))}
                >
                  {[1, 2, 3, 4].map((n) => (
                    <option key={n} value={n}>
                      {n} {n === 1 ? "image" : "images"}
                    </option>
                  ))}
                </select>
              </Field>
            </div>
          )}
          {busy === mediaMode && (
            <p role="status" className="generation-progress">
              {mediaMode === "image" ? generationPhase : "Writing your caption…"}
            </p>
          )}
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
              <button
                type="button"
                onClick={() => {
                  setPublishText(generatedText);
                  setView("publishing");
                }}
              >
                Use for publishing <ArrowRight size={12} />
              </button>
            </div>
          )}
        </form>
      </section>
      <section className="live-panel">
        {assets.length > assetLimit && (
          <Button variant="secondary" onClick={() => setAssetLimit((n) => n + 12)}>
            Show more assets
          </Button>
        )}
        <p className="live-kicker">Asset library</p>
        <h2>
          {assets.length} generated asset{assets.length === 1 ? "" : "s"}
        </h2>
        {assets.length ? (
          assets.slice(0, assetLimit).map((asset) => (
            <article className="live-asset" key={asset.id}>
              {asset.download_url && asset.media_type === "image" ? (
                <button
                  type="button"
                  className="asset-preview-button"
                  onClick={() => setPreviewAsset(asset)}
                  aria-label={`Preview ${asset.filename}`}
                >
                  {/* biome-ignore lint/performance/noImgElement: authenticated media is served by the API route. */}
                  <img
                    loading="lazy"
                    decoding="async"
                    className="asset-preview asset-preview-thumb"
                    src={asset.download_url}
                    alt={asset.prompt || asset.filename}
                  />
                </button>
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
              <button
                type="button"
                onClick={() => {
                  setCaptionAsset(asset);
                  setAssetCaption(asset.asset_metadata?.caption || generatedText || publishText);
                }}
              >
                <FileText size={14} />
                {asset.asset_metadata?.caption ? "Edit paired caption" : "Add caption & hashtags"}
              </button>
              {asset.status === "ready" && (
                <button
                  type="button"
                  onClick={() => {
                    setPublishAssetId(asset.id);
                    if (asset.asset_metadata?.caption) setPublishText(asset.asset_metadata.caption);
                    setView("publishing");
                  }}
                >
                  Use for publishing <ArrowRight size={12} />
                </button>
              )}
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
            body="Describe a visual above. Bring your own media in Publish."
          />
        )}
      </section>
    </div>
  );
  const publishingView = (
    <div className="live-columns publishing-layout">
      <div className="live-stack">
        <section className="live-panel">
          <p className="live-kicker">Controlled distribution</p>
          <h2>Publish or schedule</h2>
          <div className="live-form">
            <Field label="Media asset (optional)">
              <select
                value={publishAssetId}
                onChange={(e) => {
                  setPublishAssetId(e.target.value);
                  setExtraAssetIds((ids) => ids.filter((id) => id !== e.target.value));
                  const asset = assets.find((a) => a.id === e.target.value);
                  if (asset?.asset_metadata?.caption) setPublishText(asset.asset_metadata.caption);
                }}
              >
                <option value="">Text-only post</option>
                {assets
                  .filter((asset) => asset.status === "ready")
                  .map((asset) => (
                    <option value={asset.id} key={asset.id}>
                      {asset.filename} · {asset.media_type}
                    </option>
                  ))}
              </select>
            </Field>
            <fieldset className="batch-assets">
              <legend>Add to this batch · up to 4 assets</legend>
              <p className="live-helper">
                Mix generated images and uploads. Each asset becomes a separate post on each
                selected channel.
              </p>
              {assets
                .filter((a) => a.status === "ready" && a.id !== publishAssetId)
                .map((a) => (
                  <label key={a.id}>
                    <input
                      type="checkbox"
                      checked={extraAssetIds.includes(a.id)}
                      disabled={
                        !extraAssetIds.includes(a.id) &&
                        extraAssetIds.length + (publishAssetId ? 1 : 0) >= 4
                      }
                      onChange={() =>
                        setExtraAssetIds((ids) =>
                          ids.includes(a.id) ? ids.filter((id) => id !== a.id) : [...ids, a.id],
                        )
                      }
                    />
                    <span>{a.filename}</span>
                  </label>
                ))}
            </fieldset>
            <label className="profile-upload-control publishing-upload">
              <Upload size={15} />
              <span>{uploadingMedia ? "Uploading…" : "Upload an asset"}</span>
              <input
                type="file"
                accept="image/*,video/*"
                onChange={(event) => void uploadPublishAsset(event)}
                disabled={uploadingMedia}
              />
            </label>
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
            {workspace && (
              <CaptionEditor
                token={token}
                workspaceId={workspace.id}
                value={publishText}
                onChange={setPublishText}
                prompt={assets.find((a) => a.id === publishAssetId)?.prompt || mediaPrompt}
                previous={generatedText}
              />
            )}
            <Field
              label={`Schedule time · ${Intl.DateTimeFormat().resolvedOptions().timeZone} (device time)`}
            >
              <input
                type="datetime-local"
                value={scheduleAt}
                onChange={(e) => setScheduleAt(e.target.value)}
              />
            </Field>
            <div className="live-approval">
              <Button
                variant="secondary"
                disabled={busy === "schedule" || busy === "publish"}
                onClick={() => setPublishReview(true)}
              >
                <CalendarDays size={14} /> Schedule
              </Button>
              <Button
                disabled={busy === "schedule" || busy === "publish"}
                onClick={() => setPublishReview(false)}
              >
                <Send size={14} /> Publish now
              </Button>
            </div>
          </div>
        </section>
        <section className="live-panel">
          <p className="live-kicker">Delivery queue</p>
          <h2>Scheduled posts</h2>
          {Object.entries(delivery).map(([id, status]) => (
            <div className="live-list-row" key={id} role="status">
              <span>
                {accounts.find((a) => a.id === id.split(":")[0])?.display_name ?? "Channel"}
              </span>
              <span>{status}</span>
            </div>
          ))}
          {scheduled.length ? (
            scheduled.map((item) => (
              <div className="live-list-row" key={item.id}>
                <CalendarDays size={15} />
                <span>
                  <b>{date(item.scheduled_for)}</b>
                  <small>{item.payload.text?.slice(0, 72) || "Media post"}</small>
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
      <div className="live-stack">
        <PublishingCalendar posts={scheduled} onChoose={setScheduleAt} />
        <section className="live-panel">
          <Reveal3D>
            <p className="live-kicker">Channel connector</p>
            <h2>Connect publisher</h2>
          </Reveal3D>
          <p className="live-helper">Choose a provider to securely connect your social channel.</p>
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
                    <small>Connect channel</small>
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
                  {account.platform} · Verified {date(account.last_verified_at)}
                </small>
              </span>
              <Status value={account.status} />
              {account.status === "revoked" && account.platform !== "x" && (
                <button onClick={() => void startOAuth(account.platform as Exclude<Platform, "x">)}>
                  Reconnect
                </button>
              )}
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
  const filteredMetrics = metrics
    .filter(
      (m) =>
        (!analyticsChannel || m.social_account_id === analyticsChannel) &&
        new Date(m.collected_at).getTime() >= Date.now() - analyticsDays * 86400000,
    )
    .sort((a, b) => a.collected_at.localeCompare(b.collected_at));
  const metricTotals = filteredMetrics.reduce(
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
      <Button variant="secondary" onClick={() => setView("ml")}>
        Explore ML insights
      </Button>
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
      <div className="composer-options">
        <Field label="Channel">
          <select value={analyticsChannel} onChange={(e) => setAnalyticsChannel(e.target.value)}>
            <option value="">All channels</option>
            {accounts.map((a) => (
              <option key={a.id} value={a.id}>
                {a.display_name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Date range">
          <select value={analyticsDays} onChange={(e) => setAnalyticsDays(Number(e.target.value))}>
            <option value={7}>Last 7 days</option>
            <option value={30}>Last 30 days</option>
            <option value={90}>Last 90 days</option>
          </select>
        </Field>
      </div>
      <section className="live-panel">
        <h2>Channel performance</h2>
        {filteredMetrics.length ? (
          <>
            <AreaChart values={filteredMetrics.map((m) => m.engagements)} />
            <div className="performance-table">
              <table>
                <thead>
                  <tr>
                    <th>Post</th>
                    <th>Impressions</th>
                    <th>Engagements</th>
                    <th>Updated</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredMetrics.slice(0, 20).map((m) => (
                    <tr key={m.id}>
                      <td>{m.external_post_id}</td>
                      <td>{m.impressions}</td>
                      <td>{m.engagements}</td>
                      <td>{date(m.collected_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        ) : (
          <Empty
            icon={Send}
            title="Your story is just beginning"
            body="Connect a channel and publish a post to see performance here."
          />
        )}
      </section>
      {user?.is_admin && (
        <details>
          <summary>Operational insights</summary>
          <div className="analytics-grid">
            <ChartFrame title="Content status mix" caption={`${campaigns.length} total`}>
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
            <ChartFrame title="Platform distribution" caption="content by platform">
              <PieChart
                items={Object.entries(platformCounts).map(([label, value]) => ({ label, value }))}
              />
            </ChartFrame>
            <ChartFrame title="Content by platform" caption="ranked">
              <HorizontalBarChart
                items={Object.entries(platformCounts)
                  .sort(([, a], [, b]) => b - a)
                  .map(([label, value]) => ({ label, value }))}
              />
            </ChartFrame>
            <ChartFrame
              title="Workspace signals"
              caption="sources · content · assets"
              className="span-2"
            >
              <StackedBarChart
                groups={["Sources", "Content", "Assets"]}
                series={[
                  { name: "count", values: [documents.length, campaigns.length, assets.length] },
                ]}
              />
            </ChartFrame>
            <ChartFrame title="Content creation" caption="daily, real timestamps">
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
              caption="sources / content / assets"
              className="span-2"
            >
              <StreamChart
                series={[
                  { name: "Sources", values: documentDays.map(([, v]) => v), color: "#b8bec7" },
                  { name: "Content", values: campaignDays.map(([, v]) => v), color: "#c9a45c" },
                  { name: "Assets", values: assetDays.map(([, v]) => v), color: "#3f5d52" },
                ]}
              />
            </ChartFrame>
            <ChartFrame title="Recent activity" caption="last 28 content days">
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
              caption={`${variants.length} in current content group`}
            >
              <DotPlot
                items={variants.map((v) => ({
                  label: v.platform,
                  value: v.quality_score,
                  max: 100,
                }))}
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
            <ChartFrame
              title="Revision range per content group"
              caption="derived from revision counters"
            >
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
            <ChartFrame title="Sources vs. content" caption="waterfall of workspace growth">
              <WaterfallChart
                steps={[
                  { label: "Sources", delta: documents.length },
                  { label: "Content", delta: campaigns.length },
                  { label: "Approved", delta: approvedCount },
                  { label: "Assets", delta: assets.length },
                ]}
              />
            </ChartFrame>
            <ChartFrame title="Content volume + quality combo" caption="count + latest quality">
              <ComboChart
                bars={campaignDays.map(([, v]) => v)}
                line={campaignDays.map(() => (variantQuality.length ? variantQuality[0] : 0))}
              />
            </ChartFrame>
            <ChartFrame title="Approval completion" caption="ring">
              <ProgressRing value={approvalRate} label="approval rate" />
            </ChartFrame>
            <ChartFrame title="Platform activity" caption="bubble size = content count">
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
        </details>
      )}
    </div>
  );
  const adminView = (
    <div className="admin-dashboard">
      <header className="admin-heading">
        <p className="live-kicker">VAE administration</p>
        <h1>Payment review</h1>
        <p>Review submitted payment references and approve customer access.</p>
        <Button
          size="sm"
          variant="secondary"
          onClick={() => void loadPaymentSubmissions()}
          disabled={busy === "admin-payments"}
        >
          Refresh submissions
        </Button>
      </header>
      <section className="live-panel">
        <h2>
          {paymentsLoaded ? `${paymentSubmissions.length} submissions` : "Loading submissions"}
        </h2>
        {paymentSubmissions.length ? (
          paymentSubmissions.map((item) => (
            <article className="live-list-row" key={item.id}>
              <ShieldCheck size={16} />
              <span>
                <b>{item.display_name}</b>
                <small>
                  {item.amount} {item.currency} · {date(item.submitted_at)} ·{" "}
                  {item.utr_reference || "No payment reference"}
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
            title={paymentsLoaded ? "No payment submissions" : "Payment review is not loaded yet"}
            body="Use Refresh to retrieve the latest payment submissions."
          />
        )}
      </section>
    </div>
  );
  const content = user?.is_admin ? (
    view === "admin" ? (
      adminView
    ) : (
      <AdminDashboard
        onRefresh={() => load(token)}
        data={adminOverview}
        section={
          (["overview", "media", "publishing", "analytics"].includes(view)
            ? view
            : "overview") as AdminSection
        }
      />
    )
  ) : view === "ml" && workspace ? (
    <MlStudio
      key={workspace.id}
      token={token}
      workspaceId={workspace.id}
      initialDraft={publishText || mediaPrompt}
    />
  ) : view === "overview" ? (
    overview
  ) : view === "campaigns" ? (
    campaignsView
  ) : view === "brain" ? (
    brainView
  ) : view === "media" ? (
    mediaView
  ) : view === "analytics" ? (
    analyticsView
  ) : view === "admin" ? (
    adminView
  ) : (
    publishingView
  );
  const paletteItems = [
    ...nav.map((item) => ({
      label: `Open ${item.label}`,
      hint: "View",
      onSelect: () => {
        setView(item.id);
        if (item.id === "admin") void loadPaymentSubmissions();
      },
    })),
    { label: "Profile", hint: "Account", onSelect: () => setProfileOpen(true) },
    ...(!user?.is_admin
      ? [{ label: "Brand knowledge & sources", hint: "More", onSelect: () => setView("brain") }]
      : []),
    { label: "Sign out", hint: "Account", onSelect: () => setSignOutOpen(true) },
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
      <main
        className={cn("live-app", `view-${view}`, user?.is_admin && "admin-app")}
        data-theme={theme}
      >
        <WebglBackground variant={user?.is_admin ? "admin" : "creator"} />
        <GrainOverlay />
        {paletteOpen && (
          <CommandPalette items={paletteItems} onClose={() => setPaletteOpen(false)} />
        )}
        {tourOpen && !user?.is_admin && (
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
          {previewAsset?.download_url && (
            <motion.div
              className="asset-preview-layer"
              role="presentation"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onMouseDown={() => setPreviewAsset(null)}
            >
              <motion.div
                className="asset-preview-dialog"
                role="dialog"
                aria-modal="true"
                aria-label="Asset preview"
                initial={{ opacity: 0, scale: 0.96, y: 12 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.98, y: 8 }}
                onMouseDown={(event) => event.stopPropagation()}
              >
                <button
                  type="button"
                  className="asset-preview-close"
                  aria-label="Close asset preview"
                  onClick={() => setPreviewAsset(null)}
                >
                  <X size={18} />
                </button>
                {/* biome-ignore lint/performance/noImgElement: authenticated media preview */}
                <img
                  src={previewAsset.download_url}
                  alt={previewAsset.prompt || previewAsset.filename}
                />
                <small>{previewAsset.filename}</small>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
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
                role="dialog"
                aria-modal="true"
                aria-label="Edit profile"
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
                  aria-label="Close profile"
                  onClick={() => setProfileOpen(false)}
                >
                  <X size={16} />
                </button>
                <p className="live-kicker">Profile</p>
                <h2 className="profile-title">Edit profile</h2>
                <button
                  type="button"
                  className="profile-avatar-preview"
                  aria-label="Change profile picture"
                  disabled={profileAvatarBusy}
                  onClick={() => avatarInputRef.current?.click()}
                >
                  {profileAvatar ? (
                    // biome-ignore lint/performance/noImgElement: user-provided remote avatar URLs are not known at build time.
                    <img src={profileAvatar} alt="Profile preview" />
                  ) : (
                    <UserRound size={24} />
                  )}
                </button>
                <small className="profile-avatar-hint">
                  {profileAvatarBusy ? "Uploading…" : "Click your picture to change it"}
                </small>
                <input
                  ref={avatarInputRef}
                  hidden
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  disabled={profileAvatarBusy}
                  onChange={uploadProfileAvatar}
                />
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
                <Button
                  type="submit"
                  className="live-full-button"
                  disabled={busy === "profile" || profileAvatarBusy}
                >
                  {busy === "profile" ? "Saving…" : "Save profile"}
                </Button>
                <a href="/account-deletion">Delete account</a>
              </motion.form>
            </motion.div>
          )}
        </AnimatePresence>
        <aside className={cn("live-sidebar", sidebar && "open")}>
          <div className="live-logo brand-lockup">
            {/* biome-ignore lint/performance/noImgElement: static brand SVG */}
            <img src="/brand/vae-admin-icon.svg" alt="" />
            <span className="brand-wordmark" role="img" aria-label="VAE">
              <b>V</b>
              <em>AE</em>
            </span>
            <button onClick={() => setSidebar(false)} aria-label="Close">
              <X size={17} />
            </button>
          </div>
          <div className="live-workspace">
            <div>
              {user?.avatar_url ? (
                // biome-ignore lint/performance/noImgElement: user-provided remote avatar URLs are dynamic.
                <img src={user.avatar_url} alt="" />
              ) : (
                <UserRound size={18} />
              )}
            </div>
            <span>
              <b>{user?.brand_name || user?.display_name}</b>
              <small>
                {user?.is_admin
                  ? "Administrator"
                  : user?.account_type === "business"
                    ? "Business"
                    : "Creator"}
              </small>
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
            <button onClick={() => setPaletteOpen(true)}>
              <Menu size={17} />
              <span>More / Command</span>
            </button>
          </nav>
          <div className="live-sidebar-foot">
            <button className="live-user profile-trigger" onClick={() => setProfileOpen(true)}>
              <div>
                {user?.avatar_url ? (
                  // biome-ignore lint/performance/noImgElement: user-provided remote avatar URLs are dynamic.
                  <img src={user.avatar_url} alt="" />
                ) : (
                  <UserRound size={18} />
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
        <nav className="creator-bottom-nav" aria-label="Primary navigation">
          {(user?.is_admin ? nav : [nav[0], nav[2], nav[1], nav[3]]).map((item) => (
            <button
              key={item.id}
              aria-current={view === item.id ? "page" : undefined}
              className={cn(!user?.is_admin && item.id === "media" && "create-action")}
              onClick={() => {
                setView(item.id);
                if (item.id === "admin") void loadPaymentSubmissions();
              }}
            >
              <item.icon size={20} />
              <span>{item.label}</span>
            </button>
          ))}
          <button className="bottom-profile" onClick={() => setProfileOpen(true)}>
            {user?.avatar_url ? (
              // biome-ignore lint/performance/noImgElement: user-provided remote avatar URLs are dynamic.
              <img src={user.avatar_url} alt="" />
            ) : (
              <UserRound size={20} />
            )}
            <span>Edit profile</span>
          </button>
        </nav>
        {captionAsset && workspace && (
          <div className="confirm-layer">
            <div
              role="dialog"
              aria-modal="true"
              aria-label="Pair caption with asset"
              className="confirm-dialog caption-dialog"
            >
              <p className="live-kicker">Complete your creative</p>
              <h2>Give this visual a voice</h2>
              <p>{captionAsset.filename}</p>
              <CaptionEditor
                key={captionAsset.id}
                token={token}
                workspaceId={workspace.id}
                value={assetCaption}
                onChange={setAssetCaption}
                prompt={captionAsset.prompt || mediaPrompt}
                previous={generatedText}
              />
              <div className="confirm-actions">
                <Button variant="secondary" onClick={() => setCaptionAsset(null)}>
                  Later
                </Button>
                <Button
                  disabled={busy === "save-caption"}
                  onClick={() =>
                    void run("save-caption", async () => {
                      const asset = await api.saveAssetCaption(
                        token,
                        workspace.id,
                        captionAsset.id,
                        assetCaption,
                      );
                      setAssets((items) => items.map((a) => (a.id === asset.id ? asset : a)));
                      setPublishText(assetCaption);
                      setCaptionAsset(null);
                      setNotice("Caption and hashtags saved with your asset.");
                    })
                  }
                >
                  Save pairing
                </Button>
              </div>
            </div>
          </div>
        )}
        {publishReview !== null && (
          <div className="confirm-layer">
            <div
              className="confirm-dialog"
              role="dialog"
              aria-modal="true"
              aria-label="Review publishing"
            >
              <p className="live-kicker">Review your post</p>
              <h2>{publishReview ? "Schedule this post?" : "Publish this post?"}</h2>
              <p>
                {[publishAssetId, ...extraAssetIds]
                  .filter(Boolean)
                  .map((id) => assets.find((a) => a.id === id)?.filename)
                  .join(" · ") || "Text post"}
              </p>
              <p>
                {Math.max(1, [publishAssetId, ...extraAssetIds].filter(Boolean).length) *
                  publishAccounts.length}{" "}
                separate posts will be submitted. The caption below applies to every post in this
                batch.
              </p>
              <p>{publishText || "No caption"}</p>
              <p>
                {accounts
                  .filter((a) => publishAccounts.includes(a.id))
                  .map((a) => a.display_name)
                  .join(", ") || "No channels selected"}
              </p>
              <p>{publishReview ? date(scheduleAt) : "Publish now"}</p>
              <div className="confirm-actions">
                <Button variant="secondary" onClick={() => setPublishReview(null)}>
                  Keep editing
                </Button>
                <Button onClick={() => void publish(publishReview)}>Confirm</Button>
              </div>
            </div>
          </div>
        )}
        <section className="live-main" data-scrolled={scrolled}>
          <header className="live-topbar">
            <button onClick={() => setPaletteOpen(true)} aria-label="Open account and command menu">
              <Menu size={19} />
            </button>
            <span>
              <i /> {nav.find((item) => item.id === view)?.label ?? "Workspace"}
            </span>
            <div>
              <button className="live-command-trigger" onClick={() => setPaletteOpen(true)}>
                <Search size={14} /> <span>Search</span> <kbd>⌘K</kbd>
              </button>
              <SoundToggle enabled={soundEnabled} onChange={setSoundEnabled} />
              <button className="live-theme-toggle" onClick={toggleTheme}>
                {theme === "dark" ? <Sun size={16} /> : <Moon size={16} />}
                {theme === "dark" ? "Light" : "Dark"}
              </button>
              <button
                className="live-refresh"
                onClick={() => {
                  if (token) {
                    if (user?.is_admin && view === "admin") void loadPaymentSubmissions();
                    else void load(token);
                  }
                }}
              >
                <RefreshCw size={15} /> Refresh
              </button>
              {user?.is_admin ? (
                <Button
                  size="sm"
                  onClick={() => {
                    setView("admin");
                    void loadPaymentSubmissions();
                  }}
                >
                  <ShieldCheck size={14} /> Payment review
                </Button>
              ) : (
                <Button size="sm" onClick={() => setView("media")}>
                  <Plus size={14} /> Create media
                </Button>
              )}
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
                  role="status"
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
                  role="alert"
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
                  className={
                    !user.is_admin && view === "overview" ? "overview-layout" : "view-layout"
                  }
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
