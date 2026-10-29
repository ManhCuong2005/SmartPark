import { useId, useState } from "react";
import type { FormEvent, ReactNode } from "react";
import "./admin-auth.css";

type IconName =
  | "arrow"
  | "mail"
  | "lock"
  | "eye"
  | "eye-off"
  | "sun"
  | "moon"
  | "alert"
  | "check"
  | "back";
function AuthIcon({
  name,
  className = "",
}: {
  name: IconName;
  className?: string;
}) {
  const paths: Record<IconName, ReactNode> = {
    arrow: (
      <>
        <path d="M5 12h14M13 6l6 6-6 6" />
      </>
    ),
    back: (
      <>
        <path d="M19 12H5m6-6-6 6 6 6" />
      </>
    ),
    mail: (
      <>
        <rect x="3" y="5" width="18" height="14" rx="3" />
        <path d="m4 7 8 6 8-6" />
      </>
    ),
    lock: (
      <>
        <rect x="5" y="10" width="14" height="11" rx="3" />
        <path d="M8 10V7a4 4 0 0 1 8 0v3m-4 5v2" />
      </>
    ),
    eye: (
      <>
        <path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z" />
        <circle cx="12" cy="12" r="3" />
      </>
    ),
    "eye-off": (
      <>
        <path d="m3 3 18 18M10.6 5.1 12 5c6.5 0 10 7 10 7a18 18 0 0 1-3 3.9M6.1 6.1A21 21 0 0 0 2 12s3.5 7 10 7a13 13 0 0 0 5.9-1.9M9.9 9.9a3 3 0 0 0 4.2 4.2" />
      </>
    ),
    sun: (
      <>
        <circle cx="12" cy="12" r="4" />
        <path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5" />
      </>
    ),
    moon: (
      <path d="M20.5 13.2A8.5 8.5 0 0 1 10.8 3.5 8.5 8.5 0 1 0 20.5 13.2Z" />
    ),
    alert: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v6m0 4h.01" />
      </>
    ),
    check: <path d="m5 12 4.5 4.5L19 7" />,
  };
  return (
    <svg
      className={`auth-icon ${className}`}
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths[name]}
    </svg>
  );
}

function BrandMark() {
  return (
    <span className="auth-brand-mark" aria-hidden="true">
      <svg viewBox="0 0 40 40" fill="none">
        <path
          d="M14 29V11h8a6 6 0 0 1 0 12h-8"
          stroke="currentColor"
          strokeWidth="3.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <path
          d="m28 26 3 3-3 3"
          stroke="currentColor"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </span>
  );
}

function ParkingIllustration() {
  const id = useId().replaceAll(":", "");
  return (
    <div className="auth-illustration" aria-hidden="true">
      <div className="auth-orbit auth-orbit-one" />
      <div className="auth-orbit auth-orbit-two" />
      <svg className="auth-parking-scene" viewBox="0 0 620 380" fill="none">
        <defs>
          <linearGradient
            id={`${id}-deck`}
            x1="170"
            y1="90"
            x2="455"
            y2="320"
            gradientUnits="userSpaceOnUse"
          >
            <stop stopColor="#324B60" />
            <stop offset="1" stopColor="#1B2F40" />
          </linearGradient>
          <linearGradient id={`${id}-car`} x1="0" y1="0" x2="32" y2="67">
            <stop stopColor="#F6FCFF" />
            <stop offset="1" stopColor="#B5C9D5" />
          </linearGradient>
          <filter
            id={`${id}-shadow`}
            x="0"
            y="0"
            width="620"
            height="420"
            filterUnits="userSpaceOnUse"
          >
            <feGaussianBlur stdDeviation="13" />
          </filter>
        </defs>
        <ellipse
          cx="307"
          cy="310"
          rx="218"
          ry="36"
          fill="#030D16"
          opacity=".28"
          filter={`url(#${id}-shadow)`}
        />
        <g transform="translate(104 52) rotate(-12 210 140)">
          <rect
            x="0"
            y="27"
            width="418"
            height="257"
            rx="26"
            fill="#0D1F2C"
            stroke="#40566A"
          />
          <rect
            width="418"
            height="257"
            rx="26"
            fill={`url(#${id}-deck)`}
            stroke="#628095"
            strokeOpacity=".6"
          />
          <rect
            x="17"
            y="17"
            width="384"
            height="223"
            rx="13"
            stroke="#7390A2"
            strokeOpacity=".25"
          />
          <path d="M28 93h360M28 164h360" stroke="#698497" strokeOpacity=".7" />
          {[0, 1, 2, 3, 4, 5].map((i) => (
            <g key={i}>
              <path
                d={`M${38 + i * 62} 32v61m0 71v61`}
                stroke="#8FA6B5"
                strokeOpacity=".55"
              />
              <path
                d={`M${45 + i * 62} 99h35m0 59h-35`}
                stroke="#9DB3C1"
                strokeOpacity=".24"
              />
            </g>
          ))}
          <path
            d="M39 128h329"
            stroke="#ABC0CB"
            strokeOpacity=".5"
            strokeDasharray="12 12"
          />
          <path
            d="M90 128h217q31 0 31 31v32"
            stroke="#C8F59A"
            strokeWidth="3"
            strokeDasharray="6 7"
            opacity=".85"
          />
          <path
            d="m330 185 8 9 8-9"
            stroke="#C8F59A"
            strokeWidth="3"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <rect
            x="290"
            y="171"
            width="51"
            height="57"
            rx="7"
            fill="#C8F59A"
            fillOpacity=".1"
            stroke="#C8F59A"
            strokeDasharray="4 3"
          />
          <circle cx="315.5" cy="198" r="13" fill="#C8F59A" fillOpacity=".17" />
          <path
            d="m309 198 4 4 8-9"
            stroke="#C8F59A"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          {[
            { x: 61, y: 32, fill: "#8CB5BD" },
            { x: 185, y: 32, fill: "#C8F59A" },
            { x: 309, y: 32, fill: "#A6BAC8" },
            { x: 61, y: 175, fill: "#718BA5" },
            { x: 185, y: 175, fill: "#B7CED2" },
          ].map(({ x, y, fill }) => (
            <g key={`${x}-${y}`} transform={`translate(${x} ${y})`}>
              <rect x="-3" y="11" width="6" height="12" rx="2" fill="#142633" />
              <rect x="29" y="11" width="6" height="12" rx="2" fill="#142633" />
              <rect x="-3" y="37" width="6" height="11" rx="2" fill="#142633" />
              <rect x="29" y="37" width="6" height="11" rx="2" fill="#142633" />
              <rect width="32" height="57" rx="10" fill={fill} />
              <path d="m5 15 3-7h16l3 7-3 5H8Z" fill="#1B3343" />
              <rect
                x="7"
                y="23"
                width="18"
                height="21"
                rx="5"
                fill="#F8FFFF"
                fillOpacity=".13"
              />
              <path
                d="M7 49h18"
                stroke="#1B3343"
                strokeWidth="3"
                strokeLinecap="round"
              />
            </g>
          ))}
          <g transform="translate(98 111) rotate(90 16 28)">
            <rect width="32" height="57" rx="10" fill={`url(#${id}-car)`} />
            <path d="m5 15 3-7h16l3 7-3 5H8Z" fill="#203C4B" />
            <rect
              x="7"
              y="23"
              width="18"
              height="21"
              rx="5"
              fill="#FFFFFF"
              fillOpacity=".4"
            />
            <path
              d="M7 49h18"
              stroke="#203C4B"
              strokeWidth="3"
              strokeLinecap="round"
            />
          </g>
          <path
            d="M370 192v28m-7-7 7 7 7-7"
            stroke="#A3BACA"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </g>
        <g transform="translate(455 44)">
          <path
            d="M0 22a22 22 0 0 1 44 0c0 17-22 33-22 33S0 39 0 22Z"
            fill="#C8F59A"
          />
          <path
            d="M18 31V13h7a5 5 0 0 1 0 10h-7"
            stroke="#1B343A"
            strokeWidth="3"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </g>
        <circle cx="78" cy="180" r="4" fill="#C8F59A" />
        <circle cx="523" cy="273" r="3" fill="#93B4C0" />
        <path
          d="M81 181h38m390 93h-36"
          stroke="#94B7BE"
          strokeOpacity=".45"
          strokeDasharray="3 4"
        />
      </svg>
      <div className="auth-scene-note">
        <span className="auth-scene-note-icon">
          <AuthIcon name="check" />
        </span>
        <div>
          <span>KHÔNG GIAN KẾT NỐI</span>
          <strong>Từ đặt chỗ đến vận hành.</strong>
        </div>
      </div>
    </div>
  );
}

function AuthShell({ children }: { children: ReactNode }) {
  const [dark, setDark] = useState(() =>
    document.documentElement.classList.contains("dark"),
  );
  function toggleTheme() {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle("dark", next);
    try {
      localStorage.setItem("smartpark-theme", next ? "dark" : "light");
    } catch {
      /* Theme still works for this session. */
    }
  }
  return (
    <main className="admin-auth">
      <section
        className="auth-story"
        aria-label="SmartPark — quản lý bãi đỗ thông minh"
      >
        <div className="auth-story-grid" />
        <a
          className="auth-brand"
          href="/"
          aria-label="SmartPark — trang đăng nhập"
        >
          <BrandMark />
          <span>
            SmartPark<span className="auth-brand-caption">OWNER CONSOLE</span>
          </span>
        </a>
        <div className="auth-story-copy">
          <div className="auth-eyebrow">
            <span /> KẾT NỐI MỌI ĐIỂM ĐỖ
          </div>
          <h1>
            Mọi vị trí.
            <br />
            <span>Trong tầm tay.</span>
          </h1>
          <p>
            Một góc nhìn toàn diện để bãi đỗ của bạn
            <br className="auth-desktop-break" /> vận hành nhịp nhàng hơn mỗi
            ngày.
          </p>
        </div>
        <ParkingIllustration />
        <div className="auth-story-footer">
          <span>Đặt chỗ</span>
          <i aria-hidden="true">↗</i>
          <span>Xe vào / ra</span>
          <i aria-hidden="true">↗</i>
          <span>Doanh thu</span>
        </div>
      </section>
      <section className="auth-workspace" aria-label="Truy cập tài khoản">
        <div className="auth-workspace-top">
          <span>CỔNG QUẢN TRỊ BÃI ĐỖ</span>
          <button
            className="auth-theme-toggle"
            type="button"
            onClick={toggleTheme}
            aria-label={
              dark ? "Chuyển sang giao diện sáng" : "Chuyển sang giao diện tối"
            }
            aria-pressed={dark}
          >
            <AuthIcon name={dark ? "sun" : "moon"} />
          </button>
        </div>
        <div className="auth-form-area">{children}</div>
        <footer className="auth-workspace-footer">
          <span>SmartPark © {new Date().getFullYear()}</span>
          <span>Đỗ xe thuận tiện. Quản lý thông minh.</span>
        </footer>
      </section>
    </main>
  );
}

function authError(error: unknown) {
  const text =
    error && typeof error === "object" && "message" in error
      ? String(error.message)
      : String(error);
  if (/invalid login credentials/i.test(text))
    return "Email hoặc mật khẩu chưa chính xác. Vui lòng thử lại.";
  if (/email not confirmed/i.test(text))
    return "Vui lòng xác nhận email trước khi đăng nhập.";
  if (/rate limit|too many requests/i.test(text))
    return "Bạn đã thử nhiều lần. Vui lòng đợi một chút rồi thử lại.";
  if (/failed to fetch|network|fetch failed/i.test(text))
    return "Chưa kết nối được hệ thống. Kiểm tra mạng và thử lại.";
  return text;
}

export function AdminLogin({
  onSignIn,
  onResetPassword,
  notice = "",
}: {
  onSignIn: (email: string, password: string) => Promise<void>;
  onResetPassword: (email: string) => Promise<void>;
  notice?: string;
}) {
  const id = useId(),
    [email, setEmail] = useState(""),
    [password, setPassword] = useState(""),
    [showPassword, setShowPassword] = useState(false),
    [busy, setBusy] = useState(false),
    [mode, setMode] = useState<"login" | "reset">("login"),
    [error, setError] = useState(""),
    [sent, setSent] = useState(false),
    [capsLock, setCapsLock] = useState(false);
  function changeMode(next: "login" | "reset") {
    setMode(next);
    setError("");
    setSent(false);
  }
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    setError("");
    setSent(false);
    try {
      if (mode === "login") await onSignIn(email.trim(), password);
      else {
        await onResetPassword(email.trim());
        setSent(true);
      }
    } catch (failure) {
      setError(authError(failure));
    } finally {
      setBusy(false);
    }
  }
  return (
    <AuthShell>
      <div className="auth-form-content">
        <div className="auth-section-label">
          <span />{" "}
          {mode === "login" ? "KHÔNG GIAN CỦA BẠN" : "LẤY LẠI QUYỀN TRUY CẬP"}
        </div>
        <h2>{mode === "login" ? "Đăng nhập chủ bãi" : "Quên mật khẩu?"}</h2>
        <p className="auth-form-intro">
          {mode === "login"
            ? "Chào mừng trở lại. Sẵn sàng cho một ngày vận hành hiệu quả?"
            : "Nhập email đã đăng ký. Chúng tôi sẽ gửi liên kết để bạn đặt lại mật khẩu."}
        </p>
        <form className="auth-login-form" onSubmit={submit} aria-busy={busy}>
          <div className="auth-field">
            <label htmlFor={`${id}-email`}>Email</label>
            <div className="auth-input-wrap">
              <AuthIcon name="mail" />
              <input
                id={`${id}-email`}
                name="email"
                type="email"
                autoComplete="username"
                placeholder="tenban@congty.vn"
                required
                maxLength={254}
                value={email}
                onChange={(e) => {
                  setEmail(e.target.value);
                  setError("");
                  setSent(false);
                }}
                aria-invalid={!!error}
                aria-describedby={error ? `${id}-error` : undefined}
              />
            </div>
          </div>
          {mode === "login" && (
            <div className="auth-field">
              <div className="auth-label-row">
                <label htmlFor={`${id}-password`}>Mật khẩu</label>
                <button
                  className="auth-text-button"
                  type="button"
                  onClick={() => changeMode("reset")}
                  disabled={busy}
                >
                  Quên mật khẩu?
                </button>
              </div>
              <div className="auth-input-wrap">
                <AuthIcon name="lock" />
                <input
                  id={`${id}-password`}
                  name="password"
                  type={showPassword ? "text" : "password"}
                  autoComplete="current-password"
                  placeholder="Nhập mật khẩu của bạn"
                  required
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value);
                    setError("");
                  }}
                  onKeyUp={(e) => setCapsLock(e.getModifierState("CapsLock"))}
                  onBlur={() => setCapsLock(false)}
                  aria-invalid={!!error}
                  aria-describedby={
                    error ? `${id}-error` : capsLock ? `${id}-caps` : undefined
                  }
                />
                <button
                  className="auth-password-toggle"
                  type="button"
                  aria-label={showPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
                  aria-pressed={showPassword}
                  onClick={() => setShowPassword(!showPassword)}
                >
                  <AuthIcon name={showPassword ? "eye-off" : "eye"} />
                </button>
              </div>
              {capsLock && (
                <span className="auth-caps-hint" id={`${id}-caps`}>
                  Caps Lock đang bật.
                </span>
              )}
            </div>
          )}
          {error && (
            <div
              className="auth-feedback auth-feedback-error"
              role="alert"
              id={`${id}-error`}
            >
              <AuthIcon name="alert" />
              <p>{error}</p>
            </div>
          )}
          {(sent || notice) && !error && (
            <div className="auth-feedback auth-feedback-success" role="status">
              <AuthIcon name="check" />
              <p>
                {sent
                  ? "Nếu email hợp lệ, liên kết khôi phục sẽ được gửi đến hộp thư của bạn. Kiểm tra cả thư rác."
                  : notice}
              </p>
            </div>
          )}
          <button className="auth-submit" type="submit" disabled={busy || sent}>
            <span>
              {busy
                ? mode === "login"
                  ? "Đang đăng nhập…"
                  : "Đang gửi liên kết…"
                : mode === "login"
                  ? "Đăng nhập"
                  : sent
                    ? "Đã gửi yêu cầu"
                    : "Gửi liên kết khôi phục"}
            </span>
            {busy ? (
              <span className="auth-spinner" aria-hidden="true" />
            ) : (
              <AuthIcon name="arrow" />
            )}
          </button>
          {mode === "reset" && (
            <button
              className="auth-back-button"
              type="button"
              onClick={() => changeMode("login")}
              disabled={busy}
            >
              <AuthIcon name="back" />
              Quay lại đăng nhập
            </button>
          )}
        </form>
        <div className="auth-access-note">
          <span className="auth-access-icon">
            <AuthIcon name="lock" />
          </span>
          <p>
            Không gian dành riêng cho chủ bãi.
            <br />
            <span>Sử dụng tài khoản đã được cấp quyền truy cập.</span>
          </p>
        </div>
      </div>
    </AuthShell>
  );
}
