"use client";

import {
  type MotionValue,
  motion,
  useMotionValue,
  useReducedMotion,
  useScroll,
  useSpring,
  useTransform,
} from "motion/react";
import { type CSSProperties, type ReactNode, useCallback, useRef } from "react";

/* ------------------------------------------------------------------ *
 * The depth system.
 *
 * Three techniques, deliberately separated so each can be used where it
 * belongs instead of applying "3D" uniformly:
 *
 *   DepthCard    — per-element perspective tilt with a specular sweep.
 *   Parallax     — scroll-linked translation on a z-plane.
 *   GlassPane    — layered glassmorphism with elevation tiers.
 *
 * Everything here is transform/opacity only. No layout properties are
 * animated, so nothing in this file can trigger reflow — the browser
 * keeps it on the compositor.
 * ------------------------------------------------------------------ */

const SPRING = { stiffness: 220, damping: 26, mass: 0.6 };

export type Elevation = "flat" | "raised" | "floating" | "lifted";

/* ---------------------------------- DepthCard --------------------- */

export function DepthCard({
  children,
  className,
  elevation = "raised",
  intensity = 0,
  style,
}: {
  children: ReactNode;
  className?: string;
  elevation?: Elevation;
  /** 0 disables tilt entirely; 1 is the house default; >1 exaggerates. */
  intensity?: number;
  style?: CSSProperties;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const reduced = useReducedMotion();

  const px = useMotionValue(0);
  const py = useMotionValue(0);

  const rotateX = useSpring(useTransform(py, [-0.5, 0.5], [7 * intensity, -7 * intensity]), SPRING);
  const rotateY = useSpring(useTransform(px, [-0.5, 0.5], [-9 * intensity, 9 * intensity]), SPRING);

  // The specular highlight tracks the pointer across the surface, which is
  // what sells the tilt as a physical panel catching light rather than a
  // flat div being rotated.
  const sheenX = useTransform(px, (v) => `${50 + v * 90}%`);
  const sheenY = useTransform(py, (v) => `${50 + v * 90}%`);

  const onPointerMove = useCallback(
    (event: React.PointerEvent<HTMLDivElement>) => {
      if (reduced || intensity === 0) return;
      const node = ref.current;
      if (!node) return;
      // getBoundingClientRect on every pointermove is a forced layout. It is
      // cheap for one element but not for a grid of them, so it is read once
      // per event and never written back to during the same frame.
      const rect = node.getBoundingClientRect();
      px.set((event.clientX - rect.left) / rect.width - 0.5);
      py.set((event.clientY - rect.top) / rect.height - 0.5);
    },
    [intensity, px, py, reduced],
  );

  const onPointerLeave = useCallback(() => {
    px.set(0);
    py.set(0);
  }, [px, py]);

  return (
    <div className="depth-stage" style={style}>
      <motion.div
        ref={ref}
        className={["depth-pane", `glass-${elevation}`, className].filter(Boolean).join(" ")}
        onPointerMove={onPointerMove}
        onPointerLeave={onPointerLeave}
        style={reduced ? undefined : { rotateX, rotateY }}
      >
        {!reduced && (
          <motion.span
            aria-hidden="true"
            className="depth-pane-sheen"
            style={
              {
                "--sheen-x": sheenX,
                "--sheen-y": sheenY,
              } as unknown as CSSProperties
            }
          />
        )}
        <span className="depth-pane-content">{children}</span>
      </motion.div>
    </div>
  );
}

/* ---------------------------------- Parallax ---------------------- */

/**
 * Scroll-linked translation. `depth` is metaphorical: negative values sit
 * behind the page and move slower, positive values sit in front and move
 * faster. 0 is the content plane.
 *
 * `containerRef`, when given, is passed straight to Framer's `useScroll` as
 * its scroll container. This matters here specifically: the dashboard shell
 * sets `html, body { overflow: hidden }` and does its own scrolling inside
 * `.live-content`, so `useScroll` with no container tracks window scroll,
 * which never moves — the element would never animate. Pages where the
 * document itself scrolls (the legal pages) can omit this prop.
 */
export function Parallax({
  children,
  depth = -1,
  className,
  containerRef,
}: {
  children: ReactNode;
  depth?: number;
  className?: string;
  containerRef?: React.RefObject<HTMLElement | null>;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const reduced = useReducedMotion();
  const { scrollYProgress } = useScroll({
    target: ref,
    container: containerRef,
    offset: ["start end", "end start"],
  });

  const y = useSpring(useTransform(scrollYProgress, [0, 1], [depth * -60, depth * 60]), {
    stiffness: 110,
    damping: 30,
    mass: 0.4,
  });

  return (
    <div ref={ref} className={className}>
      <motion.div style={reduced ? undefined : { y }}>{children}</motion.div>
    </div>
  );
}

/**
 * Raw scroll progress for a section, for callers that want to drive
 * something other than translation (opacity, scale, a shader uniform).
 * Same `containerRef` caveat as [Parallax] above.
 */
export function useSectionProgress(containerRef?: React.RefObject<HTMLElement | null>): {
  ref: React.RefObject<HTMLDivElement | null>;
  progress: MotionValue<number>;
} {
  const ref = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: ref,
    container: containerRef,
    offset: ["start end", "end start"],
  });
  return { ref, progress: scrollYProgress };
}

/* ---------------------------------- GlassPane --------------------- */

export function GlassPane({
  children,
  elevation = "raised",
  className,
  as: Tag = "div",
}: {
  children: ReactNode;
  elevation?: Elevation;
  className?: string;
  as?: "div" | "section" | "aside" | "article";
}) {
  return (
    <Tag className={["glass", `glass-${elevation}`, className].filter(Boolean).join(" ")}>
      {children}
    </Tag>
  );
}

/* ---------------------------------- Reveal3D ---------------------- */

/**
 * Entrance that arrives from depth rather than sliding up — the element
 * rotates out of the page plane as it settles. Used for section headers
 * and hero content, not for list rows (it is too much repeated).
 */
export function Reveal3D({
  children,
  delay = 0,
  className,
}: {
  children: ReactNode;
  delay?: number;
  className?: string;
}) {
  const reduced = useReducedMotion();
  if (reduced) return <div className={className}>{children}</div>;

  return (
    <div className="depth-stage">
      <motion.div
        className={className}
        initial={{ opacity: 0, y: 12, rotateX: 0, scale: 1 }}
        whileInView={{ opacity: 1, y: 0, rotateX: 0, scale: 1 }}
        viewport={{ once: true, margin: "-12% 0px" }}
        transition={{ duration: 0.52, delay, ease: [0.16, 1, 0.3, 1] }}
      >
        {children}
      </motion.div>
    </div>
  );
}
