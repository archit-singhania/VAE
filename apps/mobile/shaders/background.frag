#version 460 core

// Required for FlutterFragCoord(). Without this include the engine's GLSL ->
// SPIR-V pass has no declaration for it and fails at compile time rather than
// at runtime, which is why a missing line here kills the whole Gradle build.
#include <flutter/runtime_effect.glsl>

precision highp float;

// Declaration order defines the setFloat indices used in
// shader_background.dart: uSize.x = 0, uSize.y = 1, uTime = 2.
// Do not reorder these without updating the painter.
uniform vec2 uSize;
uniform float uTime;
uniform float uAdmin;

out vec4 fragColor;

// Ashima/McEwan simplex noise (2D), condensed for a cheap mobile-friendly cost.
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x * 34.0) + 1.0) * x); }

float snoise(vec2 v) {
  const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
  vec2 i  = floor(v + dot(v, C.yy));
  vec2 x0 = v - i + dot(i, C.xx);
  vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod289(i);
  vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
  vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
  m = m * m;
  m = m * m;
  vec3 x = 2.0 * fract(p * 0.024390243902439) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
  vec3 g;
  g.x = a0.x * x0.x + h.x * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uSize;
  vec2 aspectUv = (uv - 0.5) * vec2(uSize.x / uSize.y, 1.0) + 0.5;

  float t = uTime * 0.024;

  float n1 = snoise(aspectUv * 1.3 + t);
  float n2 = snoise(aspectUv * 2.0 + vec2(5.0, -3.0) + t * 1.15);
  float field = n1 * 0.65 + n2 * 0.35;

  // Nocturne palette. Obsidian ground with a warm copper bloom high-right,
  // a cool jade one low-left, and a wide frost wash through the middle that
  // ties the two together instead of leaving them as two unrelated blobs.
  vec3 bg = vec3(0.024, 0.027, 0.039);
  vec3 creator = vec3(0.898, 0.282, 0.365);
  vec3 admin = vec3(0.310, 0.549, 1.0);
  vec3 accent = mix(creator, admin, uAdmin);
  vec3 jade = vec3(0.306, 0.612, 0.510);
  vec3 frost = vec3(0.561, 0.655, 0.761);

  float copperMask = smoothstep(0.16, 0.60, field) * smoothstep(0.05, 0.56, 1.0 - length(aspectUv - vec2(0.76, 0.24)));
  float jadeMask = smoothstep(0.14, 0.58, -field + 0.15) * smoothstep(0.05, 0.66, 1.0 - length(aspectUv - vec2(0.20, 0.80)));
  float frostMask = smoothstep(0.20, 0.58, field * 0.6 + 0.2) * smoothstep(0.05, 0.62, 1.0 - length(aspectUv - vec2(0.5, 0.52)));

  vec3 color = bg;
  color += accent * copperMask * 0.145;
  color += jade * jadeMask * 0.085;
  color += frost * frostMask * 0.042;

  // A deeper vignette than before. The content sits in glass panels with
  // their own light; pulling the edges down is what makes those panels
  // look lit rather than merely lighter than the wall behind them.
  float vignette = smoothstep(1.08, 0.22, length(aspectUv - 0.5));
  color *= mix(0.62, 1.0, vignette);

  // Fine dither. Without it, gradients this dark band visibly on OLED.
  float grain = fract(sin(dot(uv * uSize, vec2(12.9898, 78.233))) * 43758.5453);
  color += (grain - 0.5) * 0.010;

  fragColor = vec4(color, 1.0);
}
