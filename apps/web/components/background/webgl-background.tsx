"use client";

import dynamic from "next/dynamic";
import { useEffect, useState } from "react";

// Loaded client-only and code-split away from the main bundle — three.js is
// heavy and the background is purely decorative, so it should never block
// first paint or the initial JS chunk.
const WebglScene = dynamic(() => import("./webgl-scene").then((mod) => mod.WebglScene), {
  ssr: false,
});

export function WebglBackground() {
  const [ready, setReady] = useState(false);
  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    let timer = 0;
    const update = () => {
      window.clearTimeout(timer);
      if (query.matches || window.innerWidth < 768 || document.hidden) {
        setReady(false);
        return;
      }
      timer = window.setTimeout(() => setReady(true), 1200);
    };
    update();
    query.addEventListener("change", update);
    document.addEventListener("visibilitychange", update);
    return () => {
      window.clearTimeout(timer);
      query.removeEventListener("change", update);
      document.removeEventListener("visibilitychange", update);
    };
  }, []);
  return ready ? <WebglScene /> : null;
}
