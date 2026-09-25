"use client";

import { useEffect, useRef } from "react";
import * as THREE from "three";

/* ------------------------------------------------------------------ *
 * Backdrop pass — the original ambient noise field, now rendered as a
 * separate orthographic pass behind the 3D layer rather than being the
 * whole scene.
 * ------------------------------------------------------------------ */

const BACKDROP_VERT = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = vec4(position, 1.0);
  }
`;

// Ashima/McEwan simplex noise (3D), condensed.
const NOISE_GLSL = /* glsl */ `
  vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
  vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
  vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
  vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

  float snoise(vec3 v) {
    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
    vec3 i  = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;
    i = mod289(i);
    vec4 p = permute(permute(permute(
      i.z + vec4(0.0, i1.z, i2.z, 1.0))
      + i.y + vec4(0.0, i1.y, i2.y, 1.0))
      + i.x + vec4(0.0, i1.x, i2.x, 1.0));
    float n_ = 0.142857142857;
    vec3 ns = n_ * D.wyz - D.xzx;
    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);
    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);
    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);
    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));
    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);
    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
  }
`;

const BACKDROP_FRAG = /* glsl */ `
  precision highp float;
  varying vec2 vUv;
  uniform float uTime;
  uniform vec2 uResolution;
  uniform vec2 uPointer;

  ${NOISE_GLSL}

  void main() {
    vec2 uv = vUv;
    vec2 aspectUv = (uv - 0.5) * vec2(uResolution.x / uResolution.y, 1.0) + 0.5;
    // The field drifts very slightly against the pointer, which reads as the
    // backdrop sitting further away than the shards in front of it.
    aspectUv += uPointer * 0.012;

    float t = uTime * 0.024;

    float n1 = snoise(vec3(aspectUv * 1.3, t));
    float n2 = snoise(vec3(aspectUv * 2.0 + 5.0, t * 1.15));
    float field = n1 * 0.65 + n2 * 0.35;

    // Nocturne palette, matching --bg / --accent / --jade / --frost in
    // globals.css and apps/mobile/shaders/background.frag.
    vec3 bg = vec3(0.024, 0.027, 0.039);
    vec3 copper = vec3(0.898, 0.282, 0.365);
    vec3 jade = vec3(0.306, 0.612, 0.510);
    vec3 frost = vec3(0.561, 0.655, 0.761);

    float copperMask = smoothstep(0.16, 0.60, field) * smoothstep(0.05, 0.56, 1.0 - length(aspectUv - vec2(0.76, 0.24)));
    float jadeMask = smoothstep(0.14, 0.58, -field + 0.15) * smoothstep(0.05, 0.66, 1.0 - length(aspectUv - vec2(0.20, 0.80)));
    float frostMask = smoothstep(0.20, 0.58, field * 0.6 + 0.2) * smoothstep(0.05, 0.62, 1.0 - length(aspectUv - vec2(0.5, 0.52)));

    vec3 color = bg;
    color += copper * copperMask * 0.115;
    color += jade * jadeMask * 0.085;
    color += frost * frostMask * 0.042;

    // A deeper vignette than before: content sits in glass panels with their
    // own light, and pulling the edges down is what makes those panels look
    // lit rather than merely lighter than the wall behind them.
    float vignette = smoothstep(1.08, 0.22, length(aspectUv - 0.5));
    color *= mix(0.62, 1.0, vignette);

    float grain = fract(sin(dot(uv * uResolution.xy, vec2(12.9898, 78.233))) * 43758.5453);
    color += (grain - 0.5) * 0.012;

    gl_FragColor = vec4(color, 1.0);
  }
`;

/* ------------------------------------------------------------------ *
 * Depth pass — instanced copper/frost shards drifting in real 3D.
 * One draw call for every shard via InstancedMesh; the per-instance
 * animation runs on the GPU from a static `aSeed` attribute, so the CPU
 * touches nothing per frame except two uniforms.
 * ------------------------------------------------------------------ */

const SHARD_VERT = /* glsl */ `
  precision highp float;

  attribute vec4 aSeed;   // xyz = home position, w = phase
  attribute vec3 aSpin;   // per-instance rotation speed
  attribute float aScale;

  uniform float uTime;
  uniform float uDepthFade;

  varying float vFresnel;
  varying float vDepth;
  varying float vTint;

  mat3 rotation(vec3 axisSpeed, float t) {
    float x = axisSpeed.x * t;
    float y = axisSpeed.y * t;
    float z = axisSpeed.z * t;
    mat3 rx = mat3(1.0, 0.0, 0.0, 0.0, cos(x), -sin(x), 0.0, sin(x), cos(x));
    mat3 ry = mat3(cos(y), 0.0, sin(y), 0.0, 1.0, 0.0, -sin(y), 0.0, cos(y));
    mat3 rz = mat3(cos(z), -sin(z), 0.0, sin(z), cos(z), 0.0, 0.0, 0.0, 1.0);
    return rz * ry * rx;
  }

  void main() {
    mat3 rot = rotation(aSpin, uTime);
    vec3 local = rot * (position * aScale);

    // Slow buoyant drift, unique per instance via the phase seed.
    vec3 drift = vec3(
      sin(uTime * 0.11 + aSeed.w) * 0.55,
      cos(uTime * 0.09 + aSeed.w * 1.7) * 0.42,
      sin(uTime * 0.07 + aSeed.w * 0.6) * 0.30
    );

    vec3 worldPos = aSeed.xyz + drift + local;
    vec4 viewPos = modelViewMatrix * vec4(worldPos, 1.0);

    vec3 viewNormal = normalize(normalMatrix * (rot * normal));
    vec3 viewDir = normalize(-viewPos.xyz);
    // Rim term — edges catch the light, faces stay near-black. This is what
    // makes them read as bevelled metal rather than flat polygons.
    vFresnel = pow(1.0 - abs(dot(viewNormal, viewDir)), 2.6);

    vDepth = clamp((-viewPos.z - 4.0) / uDepthFade, 0.0, 1.0);
    vTint = fract(aSeed.w * 0.31);

    gl_Position = projectionMatrix * viewPos;
  }
`;

const SHARD_FRAG = /* glsl */ `
  precision highp float;

  varying float vFresnel;
  varying float vDepth;
  varying float vTint;

  uniform float uIntensity;

  void main() {
    vec3 copper = vec3(0.898, 0.282, 0.365);
    vec3 frost = vec3(0.561, 0.655, 0.761);
    vec3 jade = vec3(0.306, 0.612, 0.510);

    // Weighted toward frost rather than copper: the shards are reflected
    // light on glass, and a field of warm ones would compete with the
    // accent instead of sitting behind it.
    vec3 tint = vTint < 0.34 ? copper : (vTint < 0.86 ? frost : jade);

    // Far shards dissolve into the backdrop instead of popping at the fog
    // plane — cheaper and softer than real depth-of-field.
    float fade = 1.0 - vDepth;
    float alpha = vFresnel * fade * uIntensity;

    if (alpha < 0.004) discard;
    gl_FragColor = vec4(tint * (0.55 + vFresnel * 0.8), alpha);
  }
`;

/* ------------------------------------------------------------------ *
 * Performance tiering. The scene degrades rather than stutters: it
 * starts at a tier chosen from device hints, then watches real frame
 * times and drops a tier if it can't hold budget.
 * ------------------------------------------------------------------ */

type Tier = 0 | 1 | 2;

const TIERS = [
  { shards: 0, dpr: 1.0, intensity: 0 }, // static fallback, no 3D layer
  { shards: 34, dpr: 1.25, intensity: 0.55 },
  { shards: 72, dpr: 1.75, intensity: 0.72 },
] as const;

function initialTier(): Tier {
  if (typeof navigator === "undefined") return 1;
  const cores = navigator.hardwareConcurrency ?? 4;
  // `deviceMemory` is Chromium-only; absence is not evidence of a weak device.
  const memory = (navigator as Navigator & { deviceMemory?: number }).deviceMemory;
  const coarse = window.matchMedia("(pointer: coarse)").matches;
  if (cores <= 4 || (memory !== undefined && memory <= 4)) return 1;
  if (coarse) return 1;
  return 2;
}

export function WebglScene({ variant = "creator" }: { variant?: "creator" | "admin" }) {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    if (motionQuery.matches) return;

    let renderer: THREE.WebGLRenderer;
    try {
      renderer = new THREE.WebGLRenderer({
        antialias: false,
        alpha: false,
        powerPreference: "high-performance",
      });
    } catch {
      // No WebGL (or it was blocked). The CSS ambient glows stand in.
      return;
    }

    let tier: Tier = initialTier();
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, TIERS[tier].dpr));
    renderer.autoClear = false;
    container.appendChild(renderer.domElement);

    /* ---- backdrop ---- */
    const backdropScene = new THREE.Scene();
    const backdropCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
    const backdropUniforms = {
      uTime: { value: 0 },
      uResolution: { value: new THREE.Vector2(1, 1) },
      uPointer: { value: new THREE.Vector2(0, 0) },
    };
    const backdropGeometry = new THREE.PlaneGeometry(2, 2);
    const backdropMaterial = new THREE.ShaderMaterial({
      vertexShader: BACKDROP_VERT,
      fragmentShader: BACKDROP_FRAG,
      uniforms: backdropUniforms,
      depthTest: false,
      depthWrite: false,
    });
    backdropScene.add(new THREE.Mesh(backdropGeometry, backdropMaterial));

    /* ---- depth layer ---- */
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(46, 1, 0.1, 60);
    camera.position.set(0, 0, 14);

    const shardGeometry = new THREE.InstancedBufferGeometry();
    const source = new THREE.IcosahedronGeometry(1, 0);
    shardGeometry.index = source.index;
    shardGeometry.attributes.position = source.attributes.position;
    shardGeometry.attributes.normal = source.attributes.normal;

    const maxShards = TIERS[2].shards;
    const seeds = new Float32Array(maxShards * 4);
    const spins = new Float32Array(maxShards * 3);
    const scales = new Float32Array(maxShards);

    // Deterministic placement — a fixed seed means the composition is the
    // same on every load instead of occasionally clumping badly.
    let rngState = 0x9e3779b9;
    const rand = () => {
      rngState = (rngState * 1664525 + 1013904223) >>> 0;
      return rngState / 0xffffffff;
    };

    for (let i = 0; i < maxShards; i += 1) {
      seeds[i * 4 + 0] = (rand() - 0.5) * 26;
      seeds[i * 4 + 1] = (rand() - 0.5) * 16;
      seeds[i * 4 + 2] = -rand() * 26 - 1;
      seeds[i * 4 + 3] = rand() * 100;
      spins[i * 3 + 0] = (rand() - 0.5) * 0.16;
      spins[i * 3 + 1] = (rand() - 0.5) * 0.16;
      spins[i * 3 + 2] = (rand() - 0.5) * 0.1;
      scales[i] = 0.18 + rand() * 0.62;
    }

    shardGeometry.setAttribute("aSeed", new THREE.InstancedBufferAttribute(seeds, 4));
    shardGeometry.setAttribute("aSpin", new THREE.InstancedBufferAttribute(spins, 3));
    shardGeometry.setAttribute("aScale", new THREE.InstancedBufferAttribute(scales, 1));
    shardGeometry.instanceCount = TIERS[tier].shards;
    // Frustum culling is meaningless here: the vertex shader moves every
    // instance, so the CPU-side bounding sphere would be wrong.
    shardGeometry.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 40);

    const shardUniforms = {
      uTime: { value: 0 },
      uIntensity: { value: TIERS[tier].intensity },
      uDepthFade: { value: 30 },
    };
    const shardMaterial = new THREE.ShaderMaterial({
      vertexShader: SHARD_VERT,
      fragmentShader: SHARD_FRAG,
      uniforms: shardUniforms,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
      side: THREE.DoubleSide,
    });

    const shards = new THREE.Mesh(shardGeometry, shardMaterial);
    shards.frustumCulled = false;
    scene.add(shards);

    const applyTier = (next: Tier) => {
      tier = next;
      renderer.setPixelRatio(Math.min(window.devicePixelRatio, TIERS[tier].dpr));
      shardGeometry.instanceCount = TIERS[tier].shards;
      shardUniforms.uIntensity.value = TIERS[tier].intensity;
      setSize();
    };

    function setSize() {
      const width = container?.clientWidth || window.innerWidth;
      const height = container?.clientHeight || window.innerHeight;
      renderer.setSize(width, height, false);
      backdropUniforms.uResolution.value.set(width, height);
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
    }
    setSize();

    /* ---- pointer + scroll parallax ---- */
    const pointer = new THREE.Vector2(0, 0);
    const pointerTarget = new THREE.Vector2(0, 0);
    let scrollTarget = 0;
    let scrollEased = 0;

    const onPointerMove = (event: PointerEvent) => {
      pointerTarget.set(
        (event.clientX / window.innerWidth) * 2 - 1,
        -((event.clientY / window.innerHeight) * 2 - 1),
      );
    };
    const onScroll = () => {
      scrollTarget = window.scrollY;
    };
    window.addEventListener("pointermove", onPointerMove, { passive: true });
    window.addEventListener("scroll", onScroll, { passive: true });

    /* ---- loop ---- */
    let raf = 0;
    let paused = document.hidden;
    const clock = new THREE.Clock();
    let slowFrames = 0;

    const tick = () => {
      raf = window.requestAnimationFrame(tick);
      if (paused) return;

      const delta = Math.min(clock.getDelta(), 0.05);
      backdropUniforms.uTime.value += delta;
      shardUniforms.uTime.value += delta;

      // Frame-rate independent easing, so parallax feels identical at 60
      // and 120Hz rather than twice as fast on a ProMotion display.
      const ease = 1 - 0.001 ** delta;
      pointer.lerp(pointerTarget, ease);
      scrollEased += (scrollTarget - scrollEased) * ease;
      backdropUniforms.uPointer.value.copy(pointer);

      if (tier > 0) {
        camera.position.x = pointer.x * 1.15;
        camera.position.y = pointer.y * 0.75 - scrollEased * 0.0016;
        camera.lookAt(0, -scrollEased * 0.0008, -6);
      }

      renderer.clear();
      renderer.render(backdropScene, backdropCamera);
      if (tier > 0) renderer.render(scene, camera);

      // Sustained budget overrun drops a tier, once. Single slow frames
      // (a GC pause, a heavy React commit) are ignored.
      if (tier > 0) {
        if (delta > 0.028) slowFrames += 1;
        else slowFrames = Math.max(0, slowFrames - 1);
        if (slowFrames > 90) {
          slowFrames = 0;
          applyTier((tier - 1) as Tier);
        }
      }
    };
    raf = window.requestAnimationFrame(tick);

    const onVisibility = () => {
      paused = document.hidden;
      if (!paused) clock.getDelta();
    };
    document.addEventListener("visibilitychange", onVisibility);

    // Stop rendering entirely when the canvas is off-screen.
    const io = new IntersectionObserver(([entry]) => {
      paused = document.hidden || !entry.isIntersecting;
      if (!paused) clock.getDelta();
    });
    io.observe(container);

    const onMotionChange = () => {
      if (motionQuery.matches) applyTier(0);
    };
    motionQuery.addEventListener("change", onMotionChange);

    const resizeObserver = new ResizeObserver(setSize);
    resizeObserver.observe(container);

    const onContextLost = (event: Event) => {
      event.preventDefault();
      window.cancelAnimationFrame(raf);
    };
    renderer.domElement.addEventListener("webglcontextlost", onContextLost);

    return () => {
      window.cancelAnimationFrame(raf);
      window.removeEventListener("pointermove", onPointerMove);
      window.removeEventListener("scroll", onScroll);
      document.removeEventListener("visibilitychange", onVisibility);
      motionQuery.removeEventListener("change", onMotionChange);
      renderer.domElement.removeEventListener("webglcontextlost", onContextLost);
      io.disconnect();
      resizeObserver.disconnect();
      backdropGeometry.dispose();
      backdropMaterial.dispose();
      source.dispose();
      shardGeometry.dispose();
      shardMaterial.dispose();
      renderer.dispose();
      if (renderer.domElement.parentNode === container) {
        container.removeChild(renderer.domElement);
      }
    };
  }, []);

  return (
    <div
      ref={containerRef}
      className={`webgl-background webgl-${variant}`}
      aria-hidden="true"
      data-testid="webgl-background"
    />
  );
}
