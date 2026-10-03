"use client";

import { useEffect, useRef, useState } from "react";

/** The same artwork is framed as a landscape canvas or a natural portrait reel. */
export function HeroVideo() {
  const [motionEnabled, setMotionEnabled] = useState(false);
  const [portrait, setPortrait] = useState(false);
  const [videoReady, setVideoReady] = useState(false);
  const video = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const query = window.matchMedia("(max-width: 700px)");
    const update = () => {
      setPortrait(query.matches);
      setVideoReady(false);
    };
    update();
    query.addEventListener("change", update);
    return () => query.removeEventListener("change", update);
  }, []);

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

  useEffect(() => {
    if (motionEnabled) void video.current?.play().catch(() => undefined);
  }, [motionEnabled]);

  return (
    <div className={`hero-video-stage ${videoReady ? "has-video" : ""}`} aria-hidden="true">
      <div className={`hero-visual ${motionEnabled ? "is-animated" : ""}`}>
        <span className="hero-visual-orb hero-visual-orb-one" />
        <span className="hero-visual-orb hero-visual-orb-two" />
        <span className="hero-visual-orb hero-visual-orb-three" />
        <span className="hero-visual-grid" />
      </div>
      <video
        key={portrait ? "portrait" : "landscape"}
        ref={video}
        className="hero-video"
        autoPlay={motionEnabled}
        muted
        loop
        playsInline
        preload="metadata"
        poster={portrait ? "/video_loop_portrait-poster.jpg" : "/video_loop-poster.jpg"}
        onLoadedData={() => setVideoReady(true)}
        onCanPlay={() => {
          setVideoReady(true);
          if (motionEnabled) void video.current?.play().catch(() => undefined);
        }}
        onError={() => setVideoReady(false)}
      >
        <source src={portrait ? "/video_loop_portrait.mp4" : "/video_loop.mp4"} type="video/mp4" />
      </video>
    </div>
  );
}
