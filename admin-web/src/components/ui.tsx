import { createContext, useContext, useEffect, useId, useRef } from "react";
import type { ReactNode, ButtonHTMLAttributes } from "react";
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
      {action}
    </div>
  );
}
export function Metric({
  label,
  value,
  detail,
  icon,
  tone = "blue",
  positive = false,
}: {
  label: string;
  value: string | number;
  detail: string;
  icon: string;
  tone?: string;
  positive?: boolean;
}) {
  return (
    <article className="metric">
      <p>{label}</p>
      <strong>{value}</strong>
      <small className={positive ? "positive" : ""}>{detail}</small>
      <span className={`metric-icon ${tone}`}>
        <Asset name={icon} />
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
        : ["Hoàn thành", "Nghỉ ca", "Tạm ngưng", "Đã hủy"].includes(label)
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
  return (
    <div className="pagination">
      <span>
        Hiển thị {Math.min(count, (page - 1) * pageSize + 1)}–
        {Math.min(count, page * pageSize)} / {count} {noun}
      </span>
      <div>
        <button
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
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
  footer?: ReactNode;
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
      className="dialog"
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
        <button onClick={onClose} aria-label="Đóng hộp thoại">
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
}: {
  message?: string;
}) {
  return (
    <div className="empty-state">
      {message}
      <p>Thử thay đổi từ khóa hoặc bộ lọc.</p>
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
