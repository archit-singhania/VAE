"use client";

import { useEffect, useRef, useState } from "react";

/**
 * The landing hero uses the original `.MOV` artwork when the browser can
 * decode it, with the same layered CSS visual kept underneath as a graceful
 * fallback for browsers that do not support QuickTime containers.
 */
export function HeroVideo() {
  const [motionEnabled, setMotionEnabled] = useState(false);
  const [videoReady, setVideoReady] = useState(false);

  const video = useRef<HTMLVideoElement>(null);
  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => {
      const enabled = !query.matches && !document.hidden;
      setMotionEnabled(enabled);
      if (enabled) void video.current?.play().catch(() => undefined);
      else video.current?.pause();
    };
    update();
    query.addEventListener("change", update);
    document.addEventListener("visibilitychange", update);
    return () => {
      query.removeEventListener("change", update);
      document.removeEventListener("visibilitychange", update);
    };
  }, []);

  return (
    <div className={`hero-video-stage ${videoReady ? "has-video" : ""}`} aria-hidden="true">
      <div className={`hero-visual ${motionEnabled ? "is-animated" : ""}`}>
        <span className="hero-visual-orb hero-visual-orb-one" />
        <span className="hero-visual-orb hero-visual-orb-two" />
        <span className="hero-visual-orb hero-visual-orb-three" />
        <span className="hero-visual-grid" />
      </div>
      <video
        ref={video}
        className="hero-video"
        autoPlay={motionEnabled}
        muted
        loop
        playsInline
        preload="metadata"
        onCanPlay={() => setVideoReady(true)}
        onError={() => setVideoReady(false)}
      >
        {/* Leave the MIME type unspecified: Chromium can decode this MOV on
            some installations even though `video/quicktime` advertises no
            support, and the original landing page relied on that behavior. */}
        <source src="/video_loop.MOV" />
      </video>
    </div>
  );
}
