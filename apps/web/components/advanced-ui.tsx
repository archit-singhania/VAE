"use client";

import { Command, Mic, Sparkles, Volume2, VolumeX, X } from "lucide-react";
import { motion } from "motion/react";
import { type HTMLAttributes, type ReactNode, useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";

type DepthCardProps = HTMLAttributes<HTMLElement> & {
  children: ReactNode;
  className?: string;
  as?: "article" | "div";
};

/** Pointer-driven perspective card. CSS variables keep pointer updates off React's render path. */
export function DepthCard({ children, className = "", as = "article", ...props }: DepthCardProps) {
  const Tag = as;
  return (
    <Tag
      className={`depth-card ${className}`}
      {...props}
      onPointerMove={(event) => {
        const element = event.currentTarget;
        const rect = element.getBoundingClientRect();
        const x = (event.clientX - rect.left) / rect.width - 0.5;
        const y = (event.clientY - rect.top) / rect.height - 0.5;
        element.style.setProperty("--depth-x", `${x * 7}deg`);
        element.style.setProperty("--depth-y", `${y * -7}deg`);
        element.style.setProperty("--depth-glow-x", `${(x + 0.5) * 100}%`);
        element.style.setProperty("--depth-glow-y", `${(y + 0.5) * 100}%`);
      }}
      onPointerLeave={(event) => {
        event.currentTarget.style.setProperty("--depth-x", "0deg");
        event.currentTarget.style.setProperty("--depth-y", "0deg");
      }}
    >
      {children}
    </Tag>
  );
}

/** Small animated orb used for idle, thinking and completed AI work. */
export function AiOrb({ state = "idle" }: { state?: "idle" | "thinking" | "success" }) {
  return (
    <span className={`ai-orb ai-orb-${state}`} aria-label={`AI ${state}`} role="img">
      <span />
      <span />
      <span />
    </span>
  );
}

/** Lightweight typewriter effect for streamed-looking AI copy and contextual microcopy. */
export function TypewriterText({ text, speed = 18 }: { text: string; speed?: number }) {
  const [visible, setVisible] = useState("");
  useEffect(() => {
    if (!text) {
      setVisible("");
      return;
    }
    const prefersReducedMotion =
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReducedMotion) {
      setVisible(text);
      return;
    }
    setVisible("");
    let index = 0;
    const timer = window.setInterval(() => {
      index += 1;
      setVisible(text.slice(0, index));
      if (index >= text.length) window.clearInterval(timer);
    }, speed);
    return () => window.clearInterval(timer);
  }, [text, speed]);
  return (
    <>
      {visible}
      <span className="type-caret" aria-hidden="true" />
    </>
  );
}

/** Reveals content as it enters the scroll viewport. */
export function Reveal({
  children,
  className = "",
  ...props
}: HTMLAttributes<HTMLDivElement> & { children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  // Start visible so a clipped/embedded scroll container can never leave the
  // workspace blank. The observer still marks the element as revealed for
  // the transition state and reduced-motion users get an immediate frame.
  const [visible, setVisible] = useState(true);
  useEffect(() => {
    const node = ref.current;
    if (!node || typeof IntersectionObserver === "undefined") {
      setVisible(true);
      return;
    }
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry?.isIntersecting) {
          setVisible(true);
          observer.disconnect();
        }
      },
      { threshold: 0.12 },
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, []);
  return (
    <div ref={ref} className={`reveal ${visible ? "is-visible" : ""} ${className}`} {...props}>
      {children}
    </div>
  );
}

/** Canvas particle trails that can be pulsed by a live data mutation. */
export function ParticleField({ pulse = 0 }: { pulse?: number }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const particles = useRef<Array<{ x: number; y: number; vx: number; vy: number; life: number }>>(
    [],
  );
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext("2d");
    if (!context) return;
    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      const ratio = window.devicePixelRatio || 1;
      canvas.width = Math.max(1, Math.floor(rect.width * ratio));
      canvas.height = Math.max(1, Math.floor(rect.height * ratio));
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
    };
    resize();
    window.addEventListener("resize", resize);
    const seed = () => {
      const rect = canvas.getBoundingClientRect();
      const originX = rect.width * (0.65 + Math.random() * 0.2);
      const originY = rect.height * (0.22 + Math.random() * 0.55);
      for (let i = 0; i < 16; i += 1) {
        particles.current.push({
          x: originX,
          y: originY,
          vx: (Math.random() - 0.5) * 0.8,
          vy: (Math.random() - 0.5) * 0.8,
          life: 1,
        });
      }
    };
    seed();
    let frame = 0;
    const draw = () => {
      const rect = canvas.getBoundingClientRect();
      context.clearRect(0, 0, rect.width, rect.height);
      particles.current = particles.current.filter((particle) => particle.life > 0);
      particles.current.forEach((particle) => {
        particle.x += particle.vx;
        particle.y += particle.vy;
        particle.life -= 0.012;
        context.fillStyle = `rgba(201,164,92,${particle.life * 0.42})`;
        context.fillRect(particle.x, particle.y, 1.5, 1.5);
      });
      frame = window.requestAnimationFrame(draw);
    };
    frame = window.requestAnimationFrame(draw);
    return () => {
      window.cancelAnimationFrame(frame);
      window.removeEventListener("resize", resize);
    };
  }, []);
  useEffect(() => {
    if (pulse === 0) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    for (let i = 0; i < 22; i += 1) {
      particles.current.push({
        x: rect.width * 0.68,
        y: rect.height * 0.5,
        vx: (Math.random() - 0.5) * 2,
        vy: (Math.random() - 0.5) * 2,
        life: 1,
      });
    }
  }, [pulse]);
  return <canvas className="particle-field" ref={canvasRef} />;
}

export type PaletteItem = { label: string; hint?: string; onSelect: () => void };

export function CommandPalette({ items, onClose }: { items: PaletteItem[]; onClose: () => void }) {
  const [query, setQuery] = useState("");
  const filtered = items.filter((item) =>
    `${item.label} ${item.hint ?? ""}`.toLowerCase().includes(query.toLowerCase()),
  );
  return (
    <motion.div
      className="command-layer"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
    >
      <button
        type="button"
        className="command-backdrop"
        onClick={onClose}
        aria-label="Close command palette"
      />
      <motion.div
        className="command-dialog"
        initial={{ y: 12, scale: 0.98 }}
        animate={{ y: 0, scale: 1 }}
      >
        <div className="command-input">
          <Command size={16} />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Jump to a view or action…"
          />
          <kbd>ESC</kbd>
          <button type="button" onClick={onClose} aria-label="Close">
            <X size={15} />
          </button>
        </div>
        <p>Quick actions</p>
        {filtered.length ? (
          filtered.map((item) => (
            <button
              type="button"
              key={item.label}
              onClick={() => {
                item.onSelect();
                onClose();
              }}
            >
              <span>
                <Sparkles size={14} />
                {item.label}
              </span>
              <small>{item.hint}</small>
            </button>
          ))
        ) : (
          <div className="command-empty">No matching actions</div>
        )}
      </motion.div>
    </motion.div>
  );
}

export function Onboarding({
  onDismiss,
  onComplete,
}: {
  onDismiss: () => void;
  onComplete: () => void;
}) {
  const [step, setStep] = useState(0);
  const steps = [
    [
      "Welcome to your creative space",
      "Start with an idea. Create media, connect your channels, and share your work.",
    ],
    ["Generate with intent", "Use Create to turn a prompt into images and captions."],
    [
      "Share on your terms",
      "Choose an asset, review your caption, and publish now or schedule for later.",
    ],
  ] as const;
  const current = steps[step];
  return (
    <motion.div className="onboarding-layer" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
      <div className="onboarding-card" role="dialog" aria-modal="true" aria-label="Welcome to VAE">
        <div className="onboarding-orb">
          <AiOrb state={step === 1 ? "thinking" : "idle"} />
        </div>
        <p className="live-kicker">
          Guided setup · {step + 1}/{steps.length}
        </p>
        <h2>{current[0]}</h2>
        <p>{current[1]}</p>
        <div className="onboarding-actions">
          <button type="button" onClick={onDismiss}>
            Skip tour
          </button>
          <button
            type="button"
            className="onboarding-next"
            onClick={() => (step === steps.length - 1 ? onComplete() : setStep(step + 1))}
          >
            {step === steps.length - 1 ? "Enter workspace" : "Next"}
          </button>
        </div>
      </div>
    </motion.div>
  );
}

export function SoundToggle({
  enabled,
  onChange,
}: {
  enabled: boolean;
  onChange: (value: boolean) => void;
}) {
  return (
    <button
      type="button"
      className="sound-toggle"
      onClick={() => onChange(!enabled)}
      aria-label={enabled ? "Mute ambient sound" : "Enable ambient sound"}
    >
      {enabled ? <Volume2 size={14} /> : <VolumeX size={14} />} {enabled ? "Sound on" : "Sound off"}
    </button>
  );
}

export function VoiceIndicator({ active = false }: { active?: boolean }) {
  return (
    <span className={`voice-indicator ${active ? "is-active" : ""}`}>
      <Mic size={13} />
      <span>{active ? "Listening" : "Voice ready"}</span>
    </span>
  );
}

type SpeechRecognitionResultLike = { [index: number]: { [index: number]: { transcript: string } } };
type SpeechRecognitionLike = {
  lang: string;
  interimResults: boolean;
  maxAlternatives: number;
  onresult: ((event: { results: SpeechRecognitionResultLike }) => void) | null;
  onerror: (() => void) | null;
  onend: (() => void) | null;
  start: () => void;
};

/** Browser-native voice capture for campaign briefs; no audio is uploaded by VAE. */
export function VoiceInputButton({ onTranscript }: { onTranscript: (text: string) => void }) {
  const [active, setActive] = useState(false);
  const start = () => {
    const browserWindow = window as Window & {
      SpeechRecognition?: new () => SpeechRecognitionLike;
      webkitSpeechRecognition?: new () => SpeechRecognitionLike;
    };
    const Recognition = browserWindow.SpeechRecognition ?? browserWindow.webkitSpeechRecognition;
    if (!Recognition) return;
    const recognition = new Recognition();
    recognition.lang = navigator.language || "en-US";
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;
    recognition.onresult = (event) => {
      const transcript = event.results[0]?.[0]?.transcript?.trim();
      if (transcript) onTranscript(transcript);
    };
    recognition.onerror = () => setActive(false);
    recognition.onend = () => setActive(false);
    setActive(true);
    recognition.start();
  };
  return (
    <button
      type="button"
      className={cn("voice-input-button", active && "is-active")}
      onClick={start}
      aria-label={active ? "Listening for voice input" : "Add voice input"}
      title={active ? "Listening…" : "Speak a brief"}
    >
      <Mic size={13} /> {active ? "Listening…" : "Speak"}
    </button>
  );
}
