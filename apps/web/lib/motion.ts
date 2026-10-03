import type { Variants } from "motion/react";

// Shared easing — a slightly decelerated cubic-bezier curve that reads as
// considered rather than mechanical. Used everywhere instead of the default
// linear/ease. Typed as a plain tuple (not via `Transition["ease"]`) because
// framer-motion's `Transition` is a union and `ease` isn't present on every
// member of it, so indexing the union for the type doesn't work.
export const GLASS_SPRING = { type: "spring", stiffness: 380, damping: 32, mass: 0.9 } as const;

export const EASE = [0.16, 1, 0.3, 1] as const;

// The single orchestrated page-load sequence: heading, composer, the
// intelligence grid, and the approval strip reveal in one deliberate beat
// rather than each element animating independently.
export const pageStage: Variants = {
  hidden: {},
  show: {
    transition: {
      staggerChildren: 0.09,
      delayChildren: 0.05,
    },
  },
};

export const pageItem: Variants = {
  hidden: { opacity: 0, y: 14 },
  show: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.62, ease: EASE },
  },
};

// Overlay (backdrop) fade for the command palette and review dialog.
export const overlayFade: Variants = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { duration: 0.22, ease: EASE } },
  exit: { opacity: 0, transition: { duration: 0.18, ease: EASE } },
};

// Dialog entrance — a small scale + rise so opening reads as material
// arriving, not just appearing.
export const dialogPop: Variants = {
  hidden: { opacity: 0, scale: 0.965, y: 18, filter: "blur(4px)" },
  show: {
    opacity: 1,
    scale: 1,
    y: 0,
    filter: "blur(0px)",
    transition: GLASS_SPRING,
  },
  exit: {
    opacity: 0,
    scale: 0.97,
    y: 6,
    transition: { duration: 0.18, ease: EASE },
  },
};

// Variant preview swap inside the review dialog — content answers the
// person's click on a different variant.
export const variantSwap: Variants = {
  hidden: { opacity: 0, y: 10, scale: 1.006, filter: "blur(3px)" },
  show: { opacity: 1, y: 0, scale: 1, filter: "blur(0px)", transition: GLASS_SPRING },
  exit: {
    opacity: 0,
    y: -4,
    scale: 0.998,
    filter: "blur(2px)",
    transition: { duration: 0.12, ease: EASE },
  },
};
