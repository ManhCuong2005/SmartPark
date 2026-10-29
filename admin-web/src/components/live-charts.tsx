export function LiveBars({
  points,
}: {
  points: { label: string; value: number }[];
}) {
  const max = Math.max(1, ...points.map((p) => p.value)),
    width = 600,
    height = 180;
  return (
    <svg
      viewBox={`0 0 ${width} ${height + 35}`}
      role="img"
      aria-label="Biểu đồ dữ liệu thực tế"
      style={{ width: "100%", minHeight: 180 }}
    >
      {points.map((p, i) => {
        const w = width / Math.max(points.length, 1),
          h = (p.value / max) * (height - 20);
        return (
          <g key={p.label}>
            <rect
              x={i * w + w * 0.2}
              y={height - h}
              width={w * 0.6}
              height={h}
              rx="5"
              fill="#315fea"
            >
              <title>
                {p.label}: {p.value.toLocaleString("vi-VN")}
              </title>
            </rect>
            <text
              x={i * w + w * 0.5}
              y={height + 23}
              textAnchor="middle"
              fontSize="12"
              fill="currentColor"
            >
              {p.label}
            </text>
          </g>
        );
      })}
    </svg>
  );
}
