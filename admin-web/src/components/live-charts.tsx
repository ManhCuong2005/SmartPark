import { useId, useState } from "react";
import type { ReactNode } from "react";
import { compactMoney } from "../data/models";

export type ChartPoint = {
  label: string;
  fullLabel?: string;
  value: number;
  detail?: string;
  count?: number;
};

function computeNiceMax(rawMax: number): number {
  if (rawMax <= 0) return 10;
  const magnitude = Math.pow(10, Math.floor(Math.log10(rawMax)));
  const fraction = rawMax / magnitude;
  let niceFraction = 10;
  if (fraction <= 1) niceFraction = 1;
  else if (fraction <= 2) niceFraction = 2;
  else if (fraction <= 3) niceFraction = 3;
  else if (fraction <= 5) niceFraction = 5;
  else if (fraction <= 6) niceFraction = 6;
  else if (fraction <= 8) niceFraction = 8;
  return niceFraction * magnitude;
}

export function LiveBars({
  points,
  formatValue = (v) => v.toLocaleString("vi-VN"),
  formatAxisValue,
  emptyMessage = "Chưa có dữ liệu phát sinh trong kỳ đã chọn.",
  emptyAction,
  highlightPeak = true,
  accentColor = "#315fea",
  peakColor = "#17b29a",
  ariaLabel = "Biểu đồ dữ liệu thực tế",
  height = 210,
}: {
  points: ChartPoint[];
  formatValue?: (value: number) => string;
  formatAxisValue?: (value: number) => string;
  emptyMessage?: string;
  emptyAction?: ReactNode;
  highlightPeak?: boolean;
  accentColor?: string;
  peakColor?: string;
  ariaLabel?: string;
  height?: number;
}) {
  const [hovered, setHovered] = useState<number | null>(null);
  const gradId = useId();
  const peakGradId = useId();

  const hasData = points.length > 0 && points.some((p) => p.value > 0);
  if (!hasData) {
    return (
      <div className="chart-empty-state" role="region" aria-label={ariaLabel}>
        <div className="chart-empty-bars" aria-hidden="true">
          {[36, 58, 44, 72, 52, 64, 40].map((h, i) => (
            <span key={i} style={{ height: `${h}%` }} />
          ))}
        </div>
        <p>{emptyMessage}</p>
        {emptyAction && <div className="chart-empty-action">{emptyAction}</div>}
      </div>
    );
  }

  const rawMax = Math.max(...points.map((p) => p.value));
  const yMax = rawMax <= 3 ? 3 : computeNiceMax(rawMax);
  const peakValue = rawMax;
  const width = 620;
  const leftPad = 56;
  const rightPad = 14;
  const topPad = 16;
  const bottomPad = 28;
  const plotW = width - leftPad - rightPad;
  const plotH = height - topPad - bottomPad;
  const stepW = plotW / Math.max(points.length, 1);
  const barW = Math.min(34, Math.max(6, stepW * 0.58));
  const ticks =
    yMax === 3 ? [0, 1, 2, 3] : [0, yMax / 3, (yMax * 2) / 3, yMax];

  const axisFormatter =
    formatAxisValue ??
    ((v: number) =>
      yMax >= 1000 ? compactMoney(v) : String(Math.round(v)));

  const dense = points.length > 16;
  const activePoint =
    hovered !== null && hovered >= 0 && hovered < points.length
      ? points[hovered]
      : null;

  return (
    <div className="live-chart-wrap" onMouseLeave={() => setHovered(null)}>
      {activePoint && (
        <div className="chart-tooltip" role="status">
          <strong>{activePoint.fullLabel ?? activePoint.label}</strong>
          <span>{formatValue(activePoint.value)}</span>
          {activePoint.detail && <small>{activePoint.detail}</small>}
        </div>
      )}
      <svg
        viewBox={`0 0 ${width} ${height}`}
        role="img"
        aria-label={ariaLabel}
        className="live-chart-svg"
      >
        <defs>
          <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={accentColor} stopOpacity="1" />
            <stop offset="100%" stopColor={accentColor} stopOpacity="0.65" />
          </linearGradient>
          <linearGradient id={peakGradId} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={peakColor} stopOpacity="1" />
            <stop offset="100%" stopColor={peakColor} stopOpacity="0.7" />
          </linearGradient>
        </defs>

        {ticks.map((tick, idx) => {
          const y = topPad + plotH - (tick / yMax) * plotH;
          return (
            <g key={idx}>
              <line
                x1={leftPad}
                y1={y}
                x2={width - rightPad}
                y2={y}
                className={idx === 0 ? "chart-axis-line" : "chart-grid-line"}
              />
              <text
                x={leftPad - 8}
                y={y + 4}
                textAnchor="end"
                className="chart-y-label"
              >
                {axisFormatter(tick)}
              </text>
            </g>
          );
        })}

        {points.map((p, i) => {
          const cx = leftPad + i * stepW + stepW / 2;
          const h = p.value > 0 ? Math.max(4, (p.value / yMax) * plotH) : 0;
          const y = topPad + plotH - h;
          const isPeak = highlightPeak && p.value === peakValue && p.value > 0;
          const isHovered = hovered === i;
          const showLabel =
            !dense ||
            i === 0 ||
            i === points.length - 1 ||
            (i + 1) % 5 === 0;

          return (
            <g
              key={`${p.label}-${i}`}
              className="chart-col"
              tabIndex={0}
              onMouseEnter={() => setHovered(i)}
              onFocus={() => setHovered(i)}
              onBlur={() => setHovered(null)}
            >
              <rect
                x={leftPad + i * stepW}
                y={topPad}
                width={stepW}
                height={plotH}
                fill="transparent"
              />
              {isHovered && (
                <rect
                  x={cx - barW / 2 - 4}
                  y={topPad}
                  width={barW + 8}
                  height={plotH}
                  rx="6"
                  className="chart-hover-band"
                />
              )}
              {h > 0 ? (
                <rect
                  x={cx - barW / 2}
                  y={y}
                  width={barW}
                  height={h}
                  rx={Math.min(6, barW / 2)}
                  fill={isPeak ? `url(#${peakGradId})` : `url(#${gradId})`}
                  opacity={hovered !== null && !isHovered ? 0.55 : 1}
                >
                  <title>
                    {(p.fullLabel ?? p.label) + ": " + formatValue(p.value)}
                  </title>
                </rect>
              ) : (
                <rect
                  x={cx - barW / 2}
                  y={topPad + plotH - 2}
                  width={barW}
                  height={2}
                  rx="1"
                  className="chart-zero-dot"
                />
              )}
              {showLabel && (
                <text
                  x={cx}
                  y={height - 7}
                  textAnchor="middle"
                  className={`chart-x-label ${isHovered ? "active" : ""}`}
                >
                  {p.label}
                </text>
              )}
            </g>
          );
        })}
      </svg>
    </div>
  );
}

export function DonutRing({
  occupied,
  capacity,
  label = "Đang đỗ",
}: {
  occupied: number;
  capacity: number;
  label?: string;
}) {
  const safeCap = Math.max(0, capacity);
  const safeOcc = Math.max(0, Math.min(occupied, safeCap || occupied));
  const pct = safeCap > 0 ? Math.round((safeOcc / safeCap) * 100) : 0;
  const r = 74;
  const stroke = 20;
  const c = 2 * Math.PI * r;
  const dash = safeCap > 0 ? (safeOcc / safeCap) * c : 0;

  return (
    <div className="donut-chart-ring" aria-label={`${label}: ${pct}%`}>
      <svg viewBox="0 0 190 190" width="190" height="190" role="img" aria-label={`Công suất ${pct}%`}>
        <circle
          cx="95"
          cy="95"
          r={r}
          fill="none"
          strokeWidth={stroke}
          className="donut-track"
        />
        {dash > 0 && (
          <circle
            cx="95"
            cy="95"
            r={r}
            fill="none"
            strokeWidth={stroke}
            strokeLinecap="round"
            stroke="#315fea"
            strokeDasharray={`${dash} ${c}`}
            transform="rotate(-90 95 95)"
          />
        )}
      </svg>
      <div className="donut-center">
        <strong>{pct}%</strong>
        <span>{label}</span>
      </div>
    </div>
  );
}
