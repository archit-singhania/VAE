"use client";

/**
 * Aevra chart kit — a self-contained SVG chart library themed on the Nocturne
 * palette (copper / jade / frost, see globals.css tokens). No charting
 * dependency: every chart below is hand-rolled SVG so it inherits the same
 * restrained-glow, instrument-panel language as the rest of the workspace.
 *
 * Every component takes plain arrays of numbers/labels — callers derive
 * those from real workspace state (campaigns, variants, documents, assets,
 * scheduled posts), never from invented data.
 */

import { motion } from "motion/react";
import type { CSSProperties, ReactNode } from "react";
import { useId, useMemo } from "react";

/**
 * Series order matters: the first three are the three brand signals (copper,
 * jade, frost) and carry the same meaning here as everywhere else in the app.
 * The remaining four are deliberately desaturated neighbours rather than new
 * hues — a chart with seven equally loud colours is a chart nobody reads.
 *
 * Literals rather than `var(--…)`: these values are also fed to SVG
 * `fill`/`stroke` attributes and to gradient stop interpolation, where a
 * custom property resolves to a string the interpolation maths can't use.
 */
const PALETTE = [
  "#e5485d", // crimson — primary signal
  "#4e9c82", // jade — positive
  "#8fa7c2", // frost — informational
  "#d4a244", // amber — pending
  "#8a4d58", // ash crimson
  "#5f7a72", // ash jade
  "#ff6378", // crimson, lifted
];

function colorAt(i: number) {
  return PALETTE[i % PALETTE.length];
}

function ChartFrame({
  title,
  caption,
  height = 220,
  children,
  style,
  className,
}: {
  title: string;
  caption?: string;
  height?: number;
  children: ReactNode;
  style?: CSSProperties;
  className?: string;
}) {
  return (
    <div className={["chart-card", className].filter(Boolean).join(" ")} style={style}>
      <div className="chart-card-head">
        <b>{title}</b>
        {caption && <span>{caption}</span>}
      </div>
      <div className="chart-card-body" style={{ height }}>
        {children}
      </div>
    </div>
  );
}

function useAxisScale(values: number[], min?: number) {
  return useMemo(() => {
    const lo = min ?? Math.min(0, ...values);
    const hi = Math.max(1, ...values);
    return { lo, hi: hi === lo ? lo + 1 : hi };
  }, [values, min]);
}

/* ---------------------------------------------------------------- 1. Line */
export function LineChart({
  values,
  labels,
  color = colorAt(0),
}: {
  values: number[];
  labels?: string[];
  color?: string;
}) {
  const w = 600;
  const h = 200;
  const { lo, hi } = useAxisScale(values);
  const pts = values.map((v, i) => {
    const x = (i / Math.max(1, values.length - 1)) * (w - 24) + 12;
    const y = h - 24 - ((v - lo) / (hi - lo)) * (h - 44);
    return [x, y] as const;
  });
  const path = pts.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x},${y}`).join(" ");
  return (
    <svg
      role="img"
      aria-label="Line chart"
      viewBox={`0 0 ${w} ${h}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      <line x1="0" y1={h - 22} x2={w} y2={h - 22} stroke="var(--line)" />
      <motion.path
        d={path}
        fill="none"
        stroke={color}
        strokeWidth={2.4}
        strokeLinecap="round"
        strokeLinejoin="round"
        initial={{ pathLength: 0 }}
        whileInView={{ pathLength: 1 }}
        viewport={{ once: true }}
        transition={{ duration: 1, ease: [0.16, 1, 0.3, 1] }}
      />
      {pts.map(([x, y], i) => (
        <circle key={labels?.[i] ?? i} cx={x} cy={y} r={2.6} fill={color} />
      ))}
    </svg>
  );
}

/* ---------------------------------------------------------------- 2. Area */
export function AreaChart({ values, color = colorAt(0) }: { values: number[]; color?: string }) {
  const w = 600;
  const h = 200;
  const { lo, hi } = useAxisScale(values);
  const id = useId();
  const pts = values.map((v, i) => {
    const x = (i / Math.max(1, values.length - 1)) * (w - 24) + 12;
    const y = h - 24 - ((v - lo) / (hi - lo)) * (h - 44);
    return [x, y] as const;
  });
  const line = pts.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x},${y}`).join(" ");
  const area = `${line} L${pts[pts.length - 1]?.[0] ?? 0},${h - 22} L${pts[0]?.[0] ?? 0},${h - 22} Z`;
  return (
    <svg
      role="img"
      aria-label="Area chart"
      viewBox={`0 0 ${w} ${h}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity={0.34} />
          <stop offset="100%" stopColor={color} stopOpacity={0} />
        </linearGradient>
      </defs>
      <line x1="0" y1={h - 22} x2={w} y2={h - 22} stroke="var(--line)" />
      <motion.path
        d={area}
        fill={`url(#${id})`}
        stroke="none"
        initial={{ opacity: 0 }}
        whileInView={{ opacity: 1 }}
        viewport={{ once: true }}
        transition={{ duration: 0.8 }}
      />
      <motion.path
        d={line}
        fill="none"
        stroke={color}
        strokeWidth={2.2}
        initial={{ pathLength: 0 }}
        whileInView={{ pathLength: 1 }}
        viewport={{ once: true }}
        transition={{ duration: 1 }}
      />
    </svg>
  );
}

/* ------------------------------------------------------- 3. Stacked area (stream) */
export function StreamChart({
  series,
}: {
  series: Array<{ name: string; values: number[]; color?: string }>;
}) {
  const w = 600;
  const h = 200;
  const len = Math.max(...series.map((s) => s.values.length), 1);
  const totals = Array.from({ length: len }, (_, i) =>
    series.reduce((sum, s) => sum + (s.values[i] ?? 0), 0),
  );
  const max = Math.max(1, ...totals);
  let cumulative = new Array(len).fill(0);
  const bands = series.map((s, si) => {
    const top = cumulative.map((c, i) => c + (s.values[i] ?? 0));
    const bandTop = top.map((v) => h - 20 - (v / max) * (h - 36));
    const bandBottom = cumulative.map((v) => h - 20 - (v / max) * (h - 36));
    cumulative = top;
    const x = (i: number) => (i / Math.max(1, len - 1)) * (w - 24) + 12;
    const topPath = bandTop.map((y, i) => `${i === 0 ? "M" : "L"}${x(i)},${y}`).join(" ");
    const bottomPath = [...bandBottom]
      .map((y, i) => `L${x(i)},${y}`)
      .reverse()
      .join(" ");
    return { d: `${topPath} ${bottomPath} Z`, color: s.color ?? colorAt(si), name: s.name };
  });
  return (
    <svg
      role="img"
      aria-label="Stream chart"
      viewBox={`0 0 ${w} ${h}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      {bands.map((b) => (
        <motion.path
          key={b.name}
          d={b.d}
          fill={b.color}
          fillOpacity={0.72}
          stroke={b.color}
          strokeWidth={0.5}
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 0.8 }}
        />
      ))}
    </svg>
  );
}

/* ---------------------------------------------------------------- 4. Bar */
export function BarChart({
  values,
  labels,
  color = colorAt(0),
}: {
  values: number[];
  labels?: string[];
  color?: string;
}) {
  const w = 600;
  const h = 200;
  const max = Math.max(1, ...values);
  const gap = 10;
  const bw = (w - gap * (values.length + 1)) / Math.max(1, values.length);
  return (
    <svg
      role="img"
      aria-label="Bar chart"
      viewBox={`0 0 ${w} ${h}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      <line x1="0" y1={h - 26} x2={w} y2={h - 26} stroke="var(--line)" />
      {values.map((v, i) => {
        const bh = (v / max) * (h - 46);
        const x = gap + i * (bw + gap);
        return (
          <g key={labels?.[i] ?? i}>
            <motion.rect
              x={x}
              width={bw}
              rx={4}
              fill={color}
              y={h - 26 - bh}
              height={bh}
              initial={{ height: 0, y: h - 26 }}
              whileInView={{ height: bh, y: h - 26 - bh }}
              viewport={{ once: true }}
              transition={{ duration: 0.7, delay: i * 0.03, ease: [0.16, 1, 0.3, 1] }}
            />
            {labels?.[i] && (
              <text x={x + bw / 2} y={h - 10} textAnchor="middle" className="chart-tick">
                {labels[i]}
              </text>
            )}
          </g>
        );
      })}
    </svg>
  );
}

/* ------------------------------------------------------- 5. Horizontal bar */
export function HorizontalBarChart({
  items,
}: {
  items: Array<{ label: string; value: number; color?: string }>;
}) {
  const max = Math.max(1, ...items.map((i) => i.value));
  return (
    <div className="chart-hbar">
      {items.map((item, i) => (
        <div className="chart-hbar-row" key={item.label}>
          <span>{item.label}</span>
          <div className="chart-hbar-track">
            <motion.div
              className="chart-hbar-fill"
              style={{ background: item.color ?? colorAt(i) }}
              initial={{ width: 0 }}
              whileInView={{ width: `${(item.value / max) * 100}%` }}
              viewport={{ once: true }}
              transition={{ duration: 0.7, delay: i * 0.04, ease: [0.16, 1, 0.3, 1] }}
            />
          </div>
          <b>{item.value}</b>
        </div>
      ))}
    </div>
  );
}

/* ------------------------------------------------------------ 6. Grouped bar */
export function GroupedBarChart({
  groups,
  series,
}: {
  groups: string[];
  series: Array<{ name: string; values: number[]; color?: string }>;
}) {
  const w = 600;
  const h = 200;
  const max = Math.max(1, ...series.flatMap((s) => s.values));
  const groupGap = 14;
  const groupW = (w - groupGap * (groups.length + 1)) / Math.max(1, groups.length);
  const barW = groupW / series.length;
  return (
    <svg
      role="img"
      aria-label="Grouped bar chart"
      viewBox={`0 0 ${w} ${h}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      <line x1="0" y1={h - 26} x2={w} y2={h - 26} stroke="var(--line)" />
      {groups.map((g, gi) => {
        const gx = groupGap + gi * (groupW + groupGap);
        return (
          <g key={g}>
            {series.map((s, si) => {
              const v = s.values[gi] ?? 0;
              const bh = (v / max) * (h - 46);
              return (
                <motion.rect
                  key={s.name}
                  x={gx + si * barW}
                  width={barW - 3}
                  rx={3}
                  fill={s.color ?? colorAt(si)}
                  y={h - 26 - bh}
                  height={bh}
                  initial={{ height: 0, y: h - 26 }}
                  whileInView={{ height: bh, y: h - 26 - bh }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.6, delay: gi * 0.04 }}
                />
              );
            })}
            <text x={gx + groupW / 2} y={h - 10} textAnchor="middle" className="chart-tick">
              {g}
            </text>
          </g>
        );
      })}
    </svg>
  );
}

/* ------------------------------------------------------------ 7. Stacked bar */
export function StackedBarChart({
  groups,
  series,
}: {
  groups: string[];
  series: Array<{ name: string; values: number[]; color?: string }>;
}) {
  const w = 600;
  const h = 200;
  const totals = groups.map((_, i) => series.reduce((s, ser) => s + (ser.values[i] ?? 0), 0));
  const max = Math.max(1, ...totals);
  const gap = 16;
  const bw = (w - gap * (groups.length + 1)) / Math.max(1, groups.length);
  return (
    <svg
      role="img"
      aria-label="Stacked bar chart"
      viewBox={`0 0 ${w} ${h}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      <line x1="0" y1={h - 26} x2={w} y2={h - 26} stroke="var(--line)" />
      {groups.map((g, gi) => {
        const x = gap + gi * (bw + gap);
        let yCursor = h - 26;
        return (
          <g key={g}>
            {series.map((s, si) => {
              const v = s.values[gi] ?? 0;
              const bh = (v / max) * (h - 46);
              yCursor -= bh;
              return (
                <motion.rect
                  key={s.name}
                  x={x}
                  width={bw}
                  fill={s.color ?? colorAt(si)}
                  y={yCursor}
                  height={bh}
                  initial={{ opacity: 0 }}
                  whileInView={{ opacity: 1 }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.6, delay: gi * 0.04 }}
                />
              );
            })}
            <text x={x + bw / 2} y={h - 10} textAnchor="middle" className="chart-tick">
              {g}
            </text>
          </g>
        );
      })}
    </svg>
  );
}

/* -------------------------------------------------------------- 8. Donut */
export function DonutChart({
  items,
  size = 180,
}: {
  items: Array<{ label: string; value: number; color?: string }>;
  size?: number;
}) {
  const total = Math.max(
    1,
    items.reduce((s, i) => s + i.value, 0),
  );
  const r = size / 2 - 14;
  const c = 2 * Math.PI * r;
  let offset = 0;
  return (
    <div className="chart-donut">
      <svg
        role="img"
        aria-label="Donut chart"
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
      >
        <g transform={`translate(${size / 2},${size / 2}) rotate(-90)`}>
          <circle r={r} fill="none" stroke="var(--line)" strokeWidth={16} />
          {items.map((item, i) => {
            const frac = item.value / total;
            const dash = frac * c;
            const el = (
              <motion.circle
                key={item.label}
                r={r}
                fill="none"
                stroke={item.color ?? colorAt(i)}
                strokeWidth={16}
                strokeDasharray={`${dash} ${c - dash}`}
                strokeDashoffset={-offset}
                initial={{ opacity: 0 }}
                whileInView={{ opacity: 1 }}
                viewport={{ once: true }}
                transition={{ duration: 0.8, delay: i * 0.06 }}
              />
            );
            offset += dash;
            return el;
          })}
        </g>
        <text x="50%" y="47%" textAnchor="middle" className="chart-donut-total">
          {total}
        </text>
        <text x="50%" y="60%" textAnchor="middle" className="chart-tick">
          total
        </text>
      </svg>
      <ul className="chart-legend">
        {items.map((item, i) => (
          <li key={item.label}>
            <i style={{ background: item.color ?? colorAt(i) }} />
            {item.label} <b>{item.value}</b>
          </li>
        ))}
      </ul>
    </div>
  );
}

/* --------------------------------------------------------------- 9. Pie */
export function PieChart({
  items,
  size = 180,
}: {
  items: Array<{ label: string; value: number; color?: string }>;
  size?: number;
}) {
  const total = Math.max(
    1,
    items.reduce((s, i) => s + i.value, 0),
  );
  const r = size / 2 - 6;
  let angle = -Math.PI / 2;
  const cx = size / 2;
  const cy = size / 2;
  return (
    <div className="chart-donut">
      <svg
        role="img"
        aria-label="Pie chart"
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
      >
        {items.map((item, i) => {
          const frac = item.value / total;
          const start = angle;
          const end = angle + frac * Math.PI * 2;
          angle = end;
          const large = frac > 0.5 ? 1 : 0;
          const x1 = cx + r * Math.cos(start);
          const y1 = cy + r * Math.sin(start);
          const x2 = cx + r * Math.cos(end);
          const y2 = cy + r * Math.sin(end);
          return (
            <motion.path
              key={item.label}
              d={`M${cx},${cy} L${x1},${y1} A${r},${r} 0 ${large} 1 ${x2},${y2} Z`}
              fill={item.color ?? colorAt(i)}
              stroke="var(--bg)"
              strokeWidth={1.5}
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: i * 0.05 }}
            />
          );
        })}
      </svg>
      <ul className="chart-legend">
        {items.map((item, i) => (
          <li key={item.label}>
            <i style={{ background: item.color ?? colorAt(i) }} />
            {item.label} <b>{item.value}</b>
          </li>
        ))}
      </ul>
    </div>
  );
}

/* ---------------------------------------------------------- 10. Polar area */
export function PolarAreaChart({
  items,
  size = 190,
}: {
  items: Array<{ label: string; value: number; color?: string }>;
  size?: number;
}) {
  const max = Math.max(1, ...items.map((i) => i.value));
  const cx = size / 2;
  const cy = size / 2;
  const rMax = size / 2 - 22;
  const step = (Math.PI * 2) / items.length;
  return (
    <svg
      role="img"
      aria-label="Polar area chart"
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
    >
      {[0.33, 0.66, 1].map((f) => (
        <circle key={f} cx={cx} cy={cy} r={rMax * f} fill="none" stroke="var(--line)" />
      ))}
      {items.map((item, i) => {
        const r = (item.value / max) * rMax;
        const a0 = -Math.PI / 2 + i * step;
        const a1 = a0 + step;
        const x1 = cx + r * Math.cos(a0);
        const y1 = cy + r * Math.sin(a0);
        const x2 = cx + r * Math.cos(a1);
        const y2 = cy + r * Math.sin(a1);
        return (
          <motion.path
            key={item.label}
            d={`M${cx},${cy} L${x1},${y1} A${r},${r} 0 0 1 ${x2},${y2} Z`}
            fill={item.color ?? colorAt(i)}
            fillOpacity={0.75}
            stroke="var(--bg)"
            strokeWidth={1}
            initial={{ opacity: 0, scale: 0.7 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            style={{ transformOrigin: `${cx}px ${cy}px` }}
            transition={{ duration: 0.5, delay: i * 0.05 }}
          />
        );
      })}
    </svg>
  );
}

/* --------------------------------------------------------- 11. Radial bar */
export function RadialBarChart({
  items,
  size = 190,
}: {
  items: Array<{ label: string; value: number; color?: string }>;
  size?: number;
}) {
  const cx = size / 2;
  const cy = size / 2;
  const base = 24;
  const step = 14;
  return (
    <div className="chart-donut">
      <svg
        role="img"
        aria-label="Radial bar chart"
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
      >
        {items.map((item, i) => {
          const r = base + i * step;
          const c = 2 * Math.PI * r;
          const dash = (Math.min(100, item.value) / 100) * c;
          return (
            <g key={item.label} transform={`translate(${cx},${cy}) rotate(-90)`}>
              <circle r={r} fill="none" stroke="var(--line)" strokeWidth={8} />
              <motion.circle
                r={r}
                fill="none"
                stroke={item.color ?? colorAt(i)}
                strokeWidth={8}
                strokeLinecap="round"
                strokeDasharray={`${dash} ${c - dash}`}
                initial={{ strokeDasharray: `0 ${c}` }}
                whileInView={{ strokeDasharray: `${dash} ${c - dash}` }}
                viewport={{ once: true }}
                transition={{ duration: 0.9, delay: i * 0.08 }}
              />
            </g>
          );
        })}
      </svg>
      <ul className="chart-legend">
        {items.map((item, i) => (
          <li key={item.label}>
            <i style={{ background: item.color ?? colorAt(i) }} />
            {item.label} <b>{item.value}%</b>
          </li>
        ))}
      </ul>
    </div>
  );
}

/* -------------------------------------------------------------- 12. Gauge */
export function GaugeChart({
  value,
  max = 100,
  label,
  color = colorAt(0),
  size = 200,
}: {
  value: number;
  max?: number;
  label?: string;
  color?: string;
  size?: number;
}) {
  const cx = size / 2;
  const cy = size / 2 + 10;
  const r = size / 2 - 20;
  const frac = Math.min(1, value / max);
  const angle = Math.PI * frac;
  const x = cx - r * Math.cos(angle);
  const y = cy - r * Math.sin(angle);
  const c = Math.PI * r;
  return (
    <svg
      role="img"
      aria-label="Gauge chart"
      width={size}
      height={size / 1.7}
      viewBox={`0 0 ${size} ${size / 1.7}`}
    >
      <path
        d={`M${cx - r},${cy} A${r},${r} 0 0 1 ${cx + r},${cy}`}
        fill="none"
        stroke="var(--line)"
        strokeWidth={14}
        strokeLinecap="round"
      />
      <motion.path
        d={`M${cx - r},${cy} A${r},${r} 0 0 1 ${cx + r},${cy}`}
        fill="none"
        stroke={color}
        strokeWidth={14}
        strokeLinecap="round"
        strokeDasharray={c}
        initial={{ strokeDashoffset: c }}
        whileInView={{ strokeDashoffset: c - c * frac }}
        viewport={{ once: true }}
        transition={{ duration: 0.9, ease: [0.16, 1, 0.3, 1] }}
      />
      <circle cx={x} cy={y} r={5} fill={color} />
      <text x={cx} y={cy - 6} textAnchor="middle" className="chart-donut-total">
        {Math.round(value)}
      </text>
      {label && (
        <text x={cx} y={cy + 14} textAnchor="middle" className="chart-tick">
          {label}
        </text>
      )}
    </svg>
  );
}

/* ------------------------------------------------------- 13. Progress ring */
export function ProgressRing({
  value,
  max = 100,
  size = 96,
  color = colorAt(0),
  label,
}: {
  value: number;
  max?: number;
  size?: number;
  color?: string;
  label?: string;
}) {
  const r = size / 2 - 8;
  const c = 2 * Math.PI * r;
  const frac = Math.min(1, value / max);
  return (
    <div className="chart-ring">
      <svg
        role="img"
        aria-label="Radar chart"
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
      >
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke="var(--line)"
          strokeWidth={7}
        />
        <motion.circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={color}
          strokeWidth={7}
          strokeLinecap="round"
          strokeDasharray={c}
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
          initial={{ strokeDashoffset: c }}
          whileInView={{ strokeDashoffset: c - c * frac }}
          viewport={{ once: true }}
          transition={{ duration: 0.9, ease: [0.16, 1, 0.3, 1] }}
        />
        <text x="50%" y="53%" textAnchor="middle" className="chart-ring-value">
          {Math.round(frac * 100)}%
        </text>
      </svg>
      {label && <span>{label}</span>}
    </div>
  );
}

/* -------------------------------------------------------------- 14. Radar */
export function RadarChart({
  axes,
  series,
  size = 220,
}: {
  axes: string[];
  series: Array<{ name: string; values: number[]; color?: string }>;
  size?: number;
}) {
  const cx = size / 2;
  const cy = size / 2;
  const r = size / 2 - 28;
  const step = (Math.PI * 2) / axes.length;
  const point = (i: number, frac: number) => {
    const a = -Math.PI / 2 + i * step;
    return [cx + r * frac * Math.cos(a), cy + r * frac * Math.sin(a)] as const;
  };
  return (
    <svg
      role="img"
      aria-label="Radar chart"
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
    >
      {[0.25, 0.5, 0.75, 1].map((f) => (
        <polygon
          key={f}
          points={axes.map((_, i) => point(i, f).join(",")).join(" ")}
          fill="none"
          stroke="var(--line)"
        />
      ))}
      {axes.map((label, i) => {
        const [x, y] = point(i, 1.14);
        return (
          <text key={label} x={x} y={y} textAnchor="middle" className="chart-tick">
            {label}
          </text>
        );
      })}
      {series.map((s, si) => {
        const pts = s.values.map((v, i) => point(i, Math.min(1, v / 100)));
        return (
          <motion.polygon
            key={s.name}
            points={pts.map((p) => p.join(",")).join(" ")}
            fill={s.color ?? colorAt(si)}
            fillOpacity={0.22}
            stroke={s.color ?? colorAt(si)}
            strokeWidth={1.6}
            initial={{ opacity: 0, scale: 0.8 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            style={{ transformOrigin: `${cx}px ${cy}px` }}
            transition={{ duration: 0.6 }}
          />
        );
      })}
    </svg>
  );
}

/* ------------------------------------------------------------- 15. Scatter */
export function ScatterChart({
  points,
  xLabel,
  yLabel,
}: {
  points: Array<{ x: number; y: number; label?: string; color?: string }>;
  xLabel?: string;
  yLabel?: string;
}) {
  const w = 600;
  const h = 220;
  const xs = points.map((p) => p.x);
  const ys = points.map((p) => p.y);
  const { lo: xlo, hi: xhi } = useAxisScale(xs);
  const { lo: ylo, hi: yhi } = useAxisScale(ys);
  return (
    <svg
      role="img"
      aria-label="Scatter chart"
      viewBox={`0 0 ${w} ${h}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      <line x1="30" y1="6" x2="30" y2={h - 26} stroke="var(--line)" />
      <line x1="30" y1={h - 26} x2={w - 6} y2={h - 26} stroke="var(--line)" />
      {points.map((p, i) => {
        const x = 30 + ((p.x - xlo) / (xhi - xlo)) * (w - 46);
        const y = h - 26 - ((p.y - ylo) / (yhi - ylo)) * (h - 40);
        return (
          <motion.circle
            key={p.label ?? i}
            cx={x}
            cy={y}
            r={5}
            fill={p.color ?? colorAt(i)}
            fillOpacity={0.85}
            initial={{ opacity: 0, r: 0 }}
            whileInView={{ opacity: 1, r: 5 }}
            viewport={{ once: true }}
            transition={{ duration: 0.4, delay: i * 0.02 }}
          />
        );
      })}
      {xLabel && (
        <text x={w / 2} y={h - 6} textAnchor="middle" className="chart-tick">
          {xLabel}
        </text>
      )}
      {yLabel && (
        <text
          x={10}
          y={h / 2}
          textAnchor="middle"
          className="chart-tick"
          transform={`rotate(-90 10 ${h / 2})`}
        >
          {yLabel}
        </text>
      )}
    </svg>
  );
}

/* -------------------------------------------------------------- 16. Bubble */
export function BubbleChart({
  points,
}: {
  points: Array<{ x: number; y: number; size: number; label: string; color?: string }>;
}) {
  const w = 600;
  const h = 220;
  const xs = points.map((p) => p.x);
  const ys = points.map((p) => p.y);
  const maxSize = Math.max(1, ...points.map((p) => p.size));
  const { lo: xlo, hi: xhi } = useAxisScale(xs);
  const { lo: ylo, hi: yhi } = useAxisScale(ys);
  return (
    <svg
      role="img"
      aria-label="Bubble chart"
      viewBox={`0 0 ${w} ${h}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      <line x1="30" y1={h - 26} x2={w - 6} y2={h - 26} stroke="var(--line)" />
      {points.map((p, i) => {
        const x = 30 + ((p.x - xlo) / (xhi - xlo || 1)) * (w - 60);
        const y = h - 26 - ((p.y - ylo) / (yhi - ylo || 1)) * (h - 46);
        const r = 6 + (p.size / maxSize) * 24;
        return (
          <g key={p.label}>
            <motion.circle
              cx={x}
              cy={y}
              r={r}
              fill={p.color ?? colorAt(i)}
              fillOpacity={0.35}
              stroke={p.color ?? colorAt(i)}
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: i * 0.05 }}
            />
            <text x={x} y={y + 3} textAnchor="middle" className="chart-tick">
              {p.label}
            </text>
          </g>
        );
      })}
    </svg>
  );
}

/* -------------------------------------------------------------- 17. Funnel */
export function FunnelChart({
  stages,
}: {
  stages: Array<{ label: string; value: number; color?: string }>;
}) {
  const max = Math.max(1, ...stages.map((s) => s.value));
  return (
    <div className="chart-funnel">
      {stages.map((s, i) => {
        const pct = (s.value / max) * 100;
        return (
          <div className="chart-funnel-row" key={s.label}>
            <span>{s.label}</span>
            <motion.div
              className="chart-funnel-bar"
              style={{ background: s.color ?? colorAt(i) }}
              initial={{ width: 0 }}
              whileInView={{ width: `${pct}%` }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: i * 0.06 }}
            >
              <b>{s.value}</b>
            </motion.div>
          </div>
        );
      })}
    </div>
  );
}

/* ----------------------------------------------------------- 18. Waterfall */
export function WaterfallChart({ steps }: { steps: Array<{ label: string; delta: number }> }) {
  const w = 600;
  const h = 200;
  let running = 0;
  const cumulative = steps.map((s) => {
    const start = running;
    running += s.delta;
    return { start, end: running };
  });
  const max = Math.max(1, ...cumulative.map((c) => Math.max(c.start, c.end)));
  const gap = 14;
  const bw = (w - gap * (steps.length + 1)) / Math.max(1, steps.length);
  return (
    <svg
      role="img"
      aria-label="Waterfall chart"
      viewBox={`0 0 ${w} ${h}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      <line x1="0" y1={h - 26} x2={w} y2={h - 26} stroke="var(--line)" />
      {steps.map((s, i) => {
        const { start, end } = cumulative[i];
        const top = h - 26 - (Math.max(start, end) / max) * (h - 46);
        const bh = (Math.abs(end - start) / max) * (h - 46);
        const positive = s.delta >= 0;
        const x = gap + i * (bw + gap);
        return (
          <g key={s.label}>
            <motion.rect
              x={x}
              width={bw}
              y={top}
              height={Math.max(2, bh)}
              rx={3}
              fill={positive ? colorAt(0) : "#8a5a4c"}
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: i * 0.05 }}
            />
            <text x={x + bw / 2} y={h - 10} textAnchor="middle" className="chart-tick">
              {s.label}
            </text>
          </g>
        );
      })}
    </svg>
  );
}

/* ------------------------------------------------------------- 19. Heatmap */
export function HeatmapChart({
  rows,
  cols,
  values,
  color = colorAt(0),
}: {
  rows: string[];
  cols: string[];
  values: number[][];
  color?: string;
}) {
  const max = Math.max(1, ...values.flat());
  const cell = 34;
  return (
    <div
      className="chart-heatmap"
      style={{ gridTemplateColumns: `60px repeat(${cols.length}, ${cell}px)` }}
    >
      <span />
      {cols.map((c) => (
        <span key={c} className="chart-tick chart-heatmap-col">
          {c}
        </span>
      ))}
      {rows.map((r, ri) => (
        <>
          <span key={`${r}-label`} className="chart-tick chart-heatmap-row">
            {r}
          </span>
          {cols.map((c, ci) => {
            const v = values[ri]?.[ci] ?? 0;
            const alpha = 0.08 + (v / max) * 0.82;
            return (
              <motion.div
                key={`${r}-${c}`}
                className="chart-heatmap-cell"
                style={{ background: color, opacity: alpha }}
                title={`${r} · ${c}: ${v}`}
                initial={{ opacity: 0 }}
                whileInView={{ opacity: alpha }}
                viewport={{ once: true }}
                transition={{ duration: 0.4 }}
              />
            );
          })}
        </>
      ))}
    </div>
  );
}

/* ------------------------------------------------------ 20. Calendar heatmap */
export function CalendarHeatmap({
  days,
  color = colorAt(0),
}: {
  days: Array<{ date: string; value: number }>;
  color?: string;
}) {
  const max = Math.max(1, ...days.map((d) => d.value));
  return (
    <div className="chart-calendar">
      {days.map((d) => (
        <motion.div
          key={d.date}
          className="chart-calendar-cell"
          title={`${d.date}: ${d.value}`}
          style={{ background: color, opacity: 0.1 + (d.value / max) * 0.85 }}
          initial={{ scale: 0.4, opacity: 0 }}
          whileInView={{ scale: 1, opacity: 0.1 + (d.value / max) * 0.85 }}
          viewport={{ once: true }}
          transition={{ duration: 0.3 }}
        />
      ))}
    </div>
  );
}

/* ------------------------------------------------------------ 21. Sparkline */
export function Sparkline({
  values,
  color = colorAt(0),
  width = 120,
  height = 32,
}: {
  values: number[];
  color?: string;
  width?: number;
  height?: number;
}) {
  const { lo, hi } = useAxisScale(values);
  const pts = values.map((v, i) => {
    const x = (i / Math.max(1, values.length - 1)) * (width - 4) + 2;
    const y = height - 4 - ((v - lo) / (hi - lo)) * (height - 8);
    return [x, y] as const;
  });
  const d = pts.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x},${y}`).join(" ");
  return (
    <svg
      role="img"
      aria-label="Sparkline chart"
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      className="chart-sparkline"
    >
      <motion.path
        d={d}
        fill="none"
        stroke={color}
        strokeWidth={1.6}
        initial={{ pathLength: 0 }}
        whileInView={{ pathLength: 1 }}
        viewport={{ once: true }}
        transition={{ duration: 0.8 }}
      />
      {pts[pts.length - 1] && (
        <circle cx={pts[pts.length - 1][0]} cy={pts[pts.length - 1][1]} r={2} fill={color} />
      )}
    </svg>
  );
}

/* -------------------------------------------------------------- 22. Dot plot */
export function DotPlot({
  items,
}: {
  items: Array<{ label: string; value: number; max?: number; color?: string }>;
}) {
  return (
    <div className="chart-dotplot">
      {items.map((item, i) => {
        const max = item.max ?? 100;
        const pct = Math.min(100, (item.value / max) * 100);
        return (
          <div className="chart-dotplot-row" key={item.label}>
            <span>{item.label}</span>
            <div className="chart-dotplot-track">
              <div className="chart-dotplot-line" />
              <motion.div
                className="chart-dotplot-dot"
                style={{ background: item.color ?? colorAt(i) }}
                initial={{ left: "0%" }}
                whileInView={{ left: `${pct}%` }}
                viewport={{ once: true }}
                transition={{ duration: 0.6, delay: i * 0.04, ease: [0.16, 1, 0.3, 1] }}
              />
            </div>
            <b>{Math.round(item.value)}</b>
          </div>
        );
      })}
    </div>
  );
}

/* ----------------------------------------------------------- 23. Lollipop */
export function LollipopChart({
  items,
}: {
  items: Array<{ label: string; value: number; color?: string }>;
}) {
  const w = 600;
  const h = 200;
  const max = Math.max(1, ...items.map((i) => i.value));
  const gap = (w - 40) / Math.max(1, items.length);
  return (
    <svg
      role="img"
      aria-label="Lollipop chart"
      viewBox={`0 0 ${w} ${h}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      <line x1="0" y1={h - 26} x2={w} y2={h - 26} stroke="var(--line)" />
      {items.map((item, i) => {
        const x = 24 + i * gap + gap / 2;
        const y = h - 26 - (item.value / max) * (h - 50);
        return (
          <g key={item.label}>
            <motion.line
              x1={x}
              x2={x}
              y1={h - 26}
              y2={y}
              stroke={item.color ?? colorAt(i)}
              strokeWidth={2}
              initial={{ y2: h - 26 }}
              whileInView={{ y2: y }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: i * 0.04 }}
            />
            <motion.circle
              cx={x}
              cy={y}
              r={6}
              fill={item.color ?? colorAt(i)}
              initial={{ cy: h - 26 }}
              whileInView={{ cy: y }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: i * 0.04 }}
            />
            <text x={x} y={h - 10} textAnchor="middle" className="chart-tick">
              {item.label}
            </text>
          </g>
        );
      })}
    </svg>
  );
}

/* ----------------------------------------------------------- 24. Treemap */
export function TreemapChart({
  items,
  width = 600,
  height = 220,
}: {
  items: Array<{ label: string; value: number; color?: string }>;
  width?: number;
  height?: number;
}) {
  const total = Math.max(
    1,
    items.reduce((s, i) => s + i.value, 0),
  );
  // Simple squarified-ish single-row/column slice layout — sufficient for
  // the small item counts this dashboard ever renders.
  let cursor = 0;
  const horizontal = width >= height;
  return (
    <svg
      role="img"
      aria-label="Treemap chart"
      width="100%"
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      {items.map((item, i) => {
        const frac = item.value / total;
        const size = frac * (horizontal ? width : height);
        const rect = horizontal
          ? { x: cursor, y: 0, w: size, h: height }
          : { x: 0, y: cursor, w: width, h: size };
        cursor += size;
        return (
          <g key={item.label}>
            <motion.rect
              x={rect.x + 1}
              y={rect.y + 1}
              width={Math.max(0, rect.w - 2)}
              height={Math.max(0, rect.h - 2)}
              fill={item.color ?? colorAt(i)}
              fillOpacity={0.78}
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.5, delay: i * 0.05 }}
            />
            {rect.w > 60 && (
              <text x={rect.x + 10} y={rect.y + 20} className="chart-treemap-label">
                {item.label} · {item.value}
              </text>
            )}
          </g>
        );
      })}
    </svg>
  );
}

/* --------------------------------------------------------- 25. Candlestick */
export function CandlestickChart({
  bars,
}: {
  bars: Array<{ label: string; low: number; high: number; open: number; close: number }>;
}) {
  const w = 600;
  const h = 200;
  const all = bars.flatMap((b) => [b.low, b.high]);
  const { lo, hi } = useAxisScale(all);
  const gap = (w - 40) / Math.max(1, bars.length);
  const y = (v: number) => h - 26 - ((v - lo) / (hi - lo)) * (h - 46);
  return (
    <svg
      role="img"
      aria-label="Candlestick chart"
      viewBox={`0 0 ${w} ${h}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      <line x1="0" y1={h - 26} x2={w} y2={h - 26} stroke="var(--line)" />
      {bars.map((b, i) => {
        const x = 24 + i * gap + gap / 2;
        const up = b.close >= b.open;
        const color = up ? colorAt(0) : "#8a5a4c";
        return (
          <g key={b.label}>
            <line x1={x} x2={x} y1={y(b.low)} y2={y(b.high)} stroke={color} strokeWidth={1.4} />
            <motion.rect
              x={x - 6}
              width={12}
              y={y(Math.max(b.open, b.close))}
              height={Math.max(2, Math.abs(y(b.open) - y(b.close)))}
              fill={color}
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.4, delay: i * 0.04 }}
            />
            <text x={x} y={h - 10} textAnchor="middle" className="chart-tick">
              {b.label}
            </text>
          </g>
        );
      })}
    </svg>
  );
}

/* ------------------------------------------------------------ 26. Combo */
export function ComboChart({
  bars,
  line,
  labels,
}: {
  bars: number[];
  line: number[];
  labels?: string[];
}) {
  const w = 600;
  const h = 200;
  const maxBar = Math.max(1, ...bars);
  const { lo, hi } = useAxisScale(line);
  const gap = 8;
  const bw = (w - gap * (bars.length + 1)) / Math.max(1, bars.length);
  const linePts = line.map((v, i) => {
    const x = gap + i * (bw + gap) + bw / 2;
    const yv = h - 26 - ((v - lo) / (hi - lo)) * (h - 46);
    return [x, yv] as const;
  });
  const path = linePts.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x},${y}`).join(" ");
  return (
    <svg
      role="img"
      aria-label="Combo chart"
      viewBox={`0 0 ${w} ${h}`}
      className="chart-svg"
      preserveAspectRatio="none"
    >
      <line x1="0" y1={h - 26} x2={w} y2={h - 26} stroke="var(--line)" />
      {bars.map((v, i) => {
        const bh = (v / maxBar) * (h - 60);
        const x = gap + i * (bw + gap);
        return (
          <motion.rect
            key={labels?.[i] ?? i}
            x={x}
            width={bw}
            rx={3}
            fill={colorAt(1)}
            fillOpacity={0.55}
            y={h - 26 - bh}
            height={bh}
            initial={{ height: 0, y: h - 26 }}
            whileInView={{ height: bh, y: h - 26 - bh }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, delay: i * 0.03 }}
          />
        );
      })}
      <motion.path
        d={path}
        fill="none"
        stroke={colorAt(0)}
        strokeWidth={2.4}
        initial={{ pathLength: 0 }}
        whileInView={{ pathLength: 1 }}
        viewport={{ once: true }}
        transition={{ duration: 1 }}
      />
      {linePts.map(([x, y], i) => (
        <circle key={labels?.[i] ?? i} cx={x} cy={y} r={3} fill={colorAt(0)} />
      ))}
    </svg>
  );
}

/* --------------------------------------------------------- 27. Bullet chart */
export function BulletChart({
  items,
}: {
  items: Array<{ label: string; value: number; target: number; max: number }>;
}) {
  return (
    <div className="chart-bullet">
      {items.map((item, i) => (
        <div className="chart-bullet-row" key={item.label}>
          <span>{item.label}</span>
          <div className="chart-bullet-track">
            <motion.div
              className="chart-bullet-fill"
              style={{ background: colorAt(i) }}
              initial={{ width: 0 }}
              whileInView={{ width: `${Math.min(100, (item.value / item.max) * 100)}%` }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
            />
            <div
              className="chart-bullet-target"
              style={{ left: `${Math.min(100, (item.target / item.max) * 100)}%` }}
            />
          </div>
          <b>
            {item.value}/{item.max}
          </b>
        </div>
      ))}
    </div>
  );
}

export { ChartFrame };
