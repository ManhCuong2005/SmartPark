import { createContext, useContext, useEffect, useId, useRef } from "react";
import type { ButtonHTMLAttributes, ReactNode } from "react";
import dimensions from "../data/asset-dimensions.json";

export const FrameContext = createContext("30:5");

export function Asset({
  name,
  frame,
  className = "",
}: {
  name: string;
  frame?: string;
  className?: string;
}) {
  const context = useContext(FrameContext),
    key = `${(frame ?? context).replace(":", "_")}_img${name}`;
  const size = dimensions[key as keyof typeof dimensions];
  if (!size) throw new Error("Unknown Figma asset: " + key);
  return (
    <img
      className={`figma-asset ${className}`}
      src={`/assets/figma/${key}.svg`}
      width={size.width}
      height={size.height}
      alt=""
      aria-hidden="true"
      draggable={false}
    />
  );
}

export type UiIconName =
  | "sun"
  | "moon"
  | "refresh"
  | "chevron-left"
  | "chevron-right"
  | "car"
  | "motorcycle"
  | "receipt"
  | "download"
  | "x"
  | "check"
  | "alert"
  | "trend-up"
  | "calendar"
  | "filter"
  | "lot"
  | "clock"
  | "wallet"
  | "shield";

export function UiIcon({
  name,
  size = 18,
  className = "",
}: {
  name: UiIconName;
  size?: number;
  className?: string;
}) {
  const paths: Record<UiIconName, ReactNode> = {
    sun: (
      <>
        <circle cx="12" cy="12" r="4" />
        <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41" />
      </>
    ),
    moon: (
      <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79Z" />
    ),
    refresh: (
      <>
        <path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
        <path d="M3 3v5h5" />
        <path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16" />
        <path d="M16 16h5v5" />
      </>
    ),
    "chevron-left": <path d="m15 18-6-6 6-6" />,
    "chevron-right": <path d="m9 18 6-6-6-6" />,
    car: (
      <>
        <path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2" />
        <circle cx="7" cy="17" r="2" />
        <path d="M9 17h6" />
        <circle cx="17" cy="17" r="2" />
      </>
    ),
    motorcycle: (
      <>
        <circle cx="5.5" cy="16.5" r="3" />
        <circle cx="18.5" cy="16.5" r="3" />
        <path d="M15 6h3l2 5h-4.5l-3 5H7.5L10 9H6.5" />
        <path d="M12 6h3" />
      </>
    ),
    receipt: (
      <>
        <path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z" />
        <path d="M8 7h8M8 11h8M8 15h5" />
      </>
    ),
    download: (
      <>
        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
        <path d="m7 10 5 5 5-5" />
        <path d="M12 15V3" />
      </>
    ),
    x: <path d="M18 6 6 18M6 6l12 12" />,
    check: <path d="M20 6 9 17l-5-5" />,
    alert: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M12 8v4" />
        <path d="M12 16h.01" />
      </>
    ),
    "trend-up": (
      <>
        <path d="m22 7-8.5 8.5-5-5L2 17" />
        <path d="M16 7h6v6" />
      </>
    ),
    calendar: (
      <>
        <rect x="3" y="4" width="18" height="18" rx="2" />
        <path d="M16 2v4M8 2v4M3 10h18" />
      </>
    ),
    filter: <path d="M22 3H2l8 9.46V19l4 2v-8.54L22 3z" />,
    lot: (
      <>
        <rect x="3" y="3" width="18" height="18" rx="3" />
        <path d="M9 17V7h4a3 3 0 0 1 0 6H9" />
      </>
    ),
    clock: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v5l3 2" />
      </>
    ),
    wallet: (
      <>
        <path d="M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1" />
        <path d="M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4" />
      </>
    ),
    shield: (
      <>
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
        <path d="m9 12 2 2 4-4" />
      </>
    ),
  };

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className={`ui-icon ${className}`}
    >
      {paths[name]}
    </svg>
  );
}

export function Button({
  children,
  secondary = false,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { secondary?: boolean }) {
  return (
    <button
      {...props}
      className={`button ${secondary ? "secondary" : ""} ${props.className ?? ""}`}
    >
      {children}
    </button>
  );
}

export function Panel({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return <section className={`panel ${className}`}>{children}</section>;
}

export function PageHeading({
  title,
  subtitle,
  action,
}: {
  title: string;
  subtitle: string;
  action?: ReactNode;
}) {
  return (
    <div className="page-heading">
      <div>
        <h1>{title}</h1>
        <p>{subtitle}</p>
      </div>
      {action && <div className="page-heading-actions">{action}</div>}
    </div>
  );
}

export function Metric({
  label,
  value,
  detail,
  icon = "IconChart1",
  uiIcon,
  tone = "blue",
  positive = false,
}: {
  label: string;
  value: string | number;
  detail: string;
  icon?: string;
  uiIcon?: UiIconName;
  tone?: string;
  positive?: boolean;
}) {
  return (
    <article className="metric">
      <p>{label}</p>
      <strong>{value}</strong>
      <small className={positive ? "positive" : ""}>{detail}</small>
      <span className={`metric-icon ${tone}`}>
        {uiIcon ? <UiIcon name={uiIcon} size={22} /> : <Asset name={icon} />}
      </span>
    </article>
  );
}

export function Badge({
  children,
  tone,
}: {
  children: ReactNode;
  tone?: string;
}) {
  const label = String(children);
  const color =
    tone ??
    (["Đã xác nhận", "Hoạt động", "Đang trực"].includes(label)
      ? "green"
      : ["Sắp đầy", "Chờ đến", "Sắp vào ca"].includes(label)
        ? "amber"
        : ["Hoàn thành", "Nghỉ ca", "Tạm ngưng", "Đã hủy", "Hết hạn"].includes(
              label,
            )
          ? "gray"
          : "blue");
  return <span className={`badge ${color}`}>{children}</span>;
}

export function SearchField({
  value,
  onChange,
  placeholder,
  icon = "IconSearch1",
}: {
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
  icon?: string;
}) {
  return (
    <label className="search-field">
      <Asset name={icon} />
      <input
        aria-label={placeholder}
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      />
      {value && (
        <button
          type="button"
          aria-label="Xóa tìm kiếm"
          onClick={() => onChange("")}
        >
          ×
        </button>
      )}
    </label>
  );
}

export function Pagination({
  page,
  count,
  pageSize = 5,
  onChange,
  noun = "kết quả",
}: {
  page: number;
  count: number;
  pageSize?: number;
  onChange: (n: number) => void;
  noun?: string;
}) {
  const pages = Math.max(1, Math.ceil(count / pageSize));
  const start = count === 0 ? 0 : Math.min(count, (page - 1) * pageSize + 1);
  const end = count === 0 ? 0 : Math.min(count, page * pageSize);
  return (
    <div className="pagination">
      <span>
        Hiển thị {start}–{end} / {count} {noun}
      </span>
      <div>
        <button
          type="button"
          disabled={page === 1}
          aria-label="Trang trước"
          onClick={() => onChange(page - 1)}
        >
          ‹
        </button>
        {Array.from({ length: pages }, (_, i) => i + 1)
          .filter((p) => p === 1 || p === pages || Math.abs(p - page) <= 1)
          .map((p) => (
            <button
              type="button"
              key={p}
              aria-label={`Trang ${p}`}
              aria-current={p === page ? "page" : undefined}
              className={p === page ? "selected" : ""}
              onClick={() => onChange(p)}
            >
              {p}
            </button>
          ))}
        <button
          type="button"
          disabled={page >= pages}
          aria-label="Trang sau"
          onClick={() => onChange(page + 1)}
        >
          ›
        </button>
      </div>
    </div>
  );
}

export function Dialog({
  title,
  children,
  onClose,
  footer,
  wide = false,
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
  footer?: ReactNode;
  wide?: boolean;
}) {
  const ref = useRef<HTMLDialogElement>(null),
    id = useId();
  useEffect(() => {
    const dialog = ref.current;
    dialog?.showModal();
    return () => dialog?.close();
  }, []);
  return (
    <dialog
      ref={ref}
      className={`dialog ${wide ? "wide" : ""}`}
      aria-labelledby={id}
      onCancel={(e) => {
        e.preventDefault();
        onClose();
      }}
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="dialog-header">
        <h2 id={id}>{title}</h2>
        <button type="button" onClick={onClose} aria-label="Đóng hộp thoại">
          ×
        </button>
      </div>
      <div className="dialog-body">{children}</div>
      {footer && <div className="dialog-footer">{footer}</div>}
    </dialog>
  );
}

export function Empty({
  message = "Không tìm thấy kết quả phù hợp.",
  hint = "Thử thay đổi từ khóa hoặc bộ lọc.",
  action,
}: {
  message?: string;
  hint?: string;
  action?: ReactNode;
}) {
  return (
    <div className="empty-state">
      <strong>{message}</strong>
      {hint && <p>{hint}</p>}
      {action && <div className="empty-action">{action}</div>}
    </div>
  );
}

export function Progress({
  value,
  tone = "blue",
}: {
  value: number;
  tone?: string;
}) {
  return (
    <div
      className={`progress ${tone}`}
      role="meter"
      aria-label="Tỷ lệ sử dụng"
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={value}
    >
      <span style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
    </div>
  );
}
