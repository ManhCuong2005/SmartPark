import { useState } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import {
  Asset,
  Badge,
  Button,
  Dialog,
  FrameContext,
  UiIcon,
} from "../components/ui";
import {
  formatDateTime,
  initials,
  localDate,
  money,
  shortLot,
} from "../data/models";
import { useAdmin } from "../data/store";

export const nav = [
  {
    path: "/incidents",
    label: "Báo cáo đỗ sai",
    icon: "IconTicket",
    frame: "30:382",
  },
  { path: "/", label: "Tổng quan", icon: "IconHome", frame: "30:5" },
  {
    path: "/parking",
    label: "Quản lý bãi đỗ",
    icon: "IconBuilding",
    frame: "30:177",
  },
  { path: "/bookings", label: "Đặt chỗ", icon: "IconTicket", frame: "30:382" },
  { path: "/staff", label: "Nhân viên", icon: "IconUsers", frame: "30:553" },
  {
    path: "/reports",
    label: "Báo cáo doanh thu",
    icon: "IconChart",
    frame: "30:735",
  },
  {
    path: "/settings",
    label: "Cài đặt & giá vé",
    icon: "IconSettings",
    frame: "30:894",
  },
];

export function Layout() {
  const { pathname, search: routeSearch } = useLocation(),
    navigate = useNavigate(),
    { data, refresh, command, signOut, profile, online, syncing, lastUpdated } =
      useAdmin();
  const [mobile, setMobile] = useState(false),
    [help, setHelp] = useState(false),
    [notifications, setNotifications] = useState(false),
    [account, setAccount] = useState(false),
    [search, setSearch] = useState(""),
    [dark, setDark] = useState(() =>
      document.documentElement.classList.contains("dark"),
    );

  const frame = nav.find((n) => n.path === pathname)?.frame ?? "30:5";
  const ownerName = String(profile.name ?? "").trim() || "Admin SmartPark";
  const ownerEmail = String(profile.email ?? "").trim();
  const ownerInitials = initials(ownerName, "AD");
  const ownerShortName = ownerName.split(/\s+/).slice(-1)[0] || "Quản trị";

  const today = localDate();
  const pendingCheckinCount = data.bookings.filter(
    (b) => b.status === "Đã xác nhận",
  ).length;
  const activeParked = data.bookings.filter((b) => b.status === "Đang sử dụng");
  const nowMs = Date.now();
  const overdueCount = activeParked.filter((b) => {
    const endMs = b.endsAt ? new Date(b.endsAt).getTime() : NaN;
    return !Number.isNaN(endMs) && endMs < nowMs;
  }).length;
  const todayRevenue = data.payments
    .filter((p) => localDate(p.paidAt) === today)
    .reduce((sum, p) => sum + p.amount, 0);
  const unreadDbNotifications = data.notifications.filter((n) => !n.read);
  const hasUnreadAlerts = unreadDbNotifications.length > 0 || overdueCount > 0;

  const q = search.toLocaleLowerCase("vi").trim();
  const hits = q
    ? [
        ...data.lots
          .filter((l) =>
            `${l.name} ${l.area}`.toLocaleLowerCase("vi").includes(q),
          )
          .slice(0, 3)
          .map((l) => ({
            label: `${l.name} (${l.occupied}/${l.capacity})`,
            kind: "Bãi đỗ",
            path: "/parking?q=" + encodeURIComponent(l.name),
          })),
        ...data.bookings
          .filter((b) =>
            `${b.id} ${b.customer} ${b.plate} ${b.slotCode}`
              .toLocaleLowerCase("vi")
              .includes(q),
          )
          .slice(0, 3)
          .map((b) => ({
            label: `${b.plate} · ${b.customer || "Khách đặt chỗ"}`,
            kind: "Đặt chỗ",
            path: "/bookings?q=" + encodeURIComponent(b.plate || b.id),
          })),
        ...data.staff
          .filter((s) =>
            `${s.name} ${s.email} ${shortLot(data.lots.find((l) => l.id === s.lotId))}`
              .toLocaleLowerCase("vi")
              .includes(q),
          )
          .slice(0, 3)
          .map((s) => ({
            label: `${s.name || s.email}`,
            kind: "Nhân viên",
            path: "/staff?q=" + encodeURIComponent(s.email || s.name),
          })),
        ...data.payments
          .filter((p) =>
            `${p.plate} ${p.customerName} ${p.lotName} ${p.id}`
              .toLocaleLowerCase("vi")
              .includes(q),
          )
          .slice(0, 2)
          .map((p) => ({
            label: `${p.plate || p.id.slice(0, 8)} · ${money(p.amount)}`,
            kind: "Giao dịch",
            path: "/reports?q=" + encodeURIComponent(p.plate || p.id),
          })),
      ]
    : [];

  return (
    <FrameContext.Provider value={frame}>
      <div className="admin-app">
        <a className="skip-link" href="#main-content">
          Đến nội dung chính
        </a>
        {mobile && (
          <button
            type="button"
            className="sidebar-backdrop"
            aria-label="Đóng menu"
            onClick={() => setMobile(false)}
          />
        )}
        <aside
          className={`sidebar ${mobile ? "is-open" : ""}`}
          aria-label="Menu quản trị"
        >
          <NavLink to="/" className="brand" onClick={() => setMobile(false)}>
            <span className="brand-mark">
              <Asset name="IconCar" />
            </span>
            <span>
              <strong>SmartPark</strong>
              <small>ADMIN CONSOLE</small>
            </span>
          </NavLink>
          <div className="sidebar-line" />
          <p className="menu-label">MENU CHÍNH</p>
          <nav>
            {nav.map((n) => (
              <NavLink
                key={n.path}
                to={n.path}
                end={n.path === "/"}
                onClick={() => setMobile(false)}
                className={({ isActive }) =>
                  isActive ? "nav-item active" : "nav-item"
                }
              >
                <Asset name={n.icon} />
                <span>{n.label}</span>
              </NavLink>
            ))}
          </nav>
          <div className="sidebar-bottom">
            <button
              type="button"
              className="support"
              onClick={() => setHelp(true)}
            >
              <span>
                <Asset name="IconHelp" />
                <strong>Trợ giúp quản lý</strong>
              </span>
              <small>
                Đồng bộ thời gian thực với ứng dụng Khách hàng và Nhân viên.
              </small>
            </button>
            <button
              type="button"
              className="sidebar-account"
              onClick={() => setAccount(true)}
            >
              <span className="admin-initials">{ownerInitials}</span>
              <span>
                <strong>{ownerName}</strong>
                <small>Chủ bãi SmartPark</small>
              </span>
            </button>
          </div>
        </aside>
        <div className="workspace">
          <header className="topbar">
            <button
              type="button"
              className="mobile-menu"
              aria-label="Mở menu quản trị"
              onClick={() => setMobile(true)}
            >
              ☰
            </button>
            <div className="global-search">
              <Asset name="IconSearch" />
              <input
                aria-label="Tìm kiếm toàn hệ thống"
                placeholder="Tìm bãi đỗ, biển số, nhân viên, giao dịch..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Escape") setSearch("");
                }}
              />
              {q && (
                <div className="global-results">
                  {hits.length ? (
                    hits.map((h, i) => (
                      <button
                        type="button"
                        key={h.path + i}
                        onClick={() => {
                          navigate(h.path);
                          setSearch("");
                        }}
                      >
                        <span>{h.label}</span>
                        <small>{h.kind}</small>
                      </button>
                    ))
                  ) : (
                    <p>Không tìm thấy kết quả phù hợp.</p>
                  )}
                </div>
              )}
            </div>
            <div className="topbar-actions">
              <span
                className={`demo-label ${online ? "is-online" : "is-offline"}`}
                title={
                  lastUpdated
                    ? `Cập nhật gần nhất: ${lastUpdated}`
                    : "Đang chờ đồng bộ Supabase"
                }
              >
                {online ? "Supabase · đã kết nối" : "Chưa kết nối"}
              </span>
              <button
                type="button"
                className="icon-tool-button"
                aria-label="Đồng bộ dữ liệu ngay"
                title={
                  lastUpdated
                    ? `Đồng bộ dữ liệu (${lastUpdated})`
                    : "Đồng bộ dữ liệu"
                }
                disabled={syncing}
                onClick={() => void refresh()}
              >
                <UiIcon
                  name="refresh"
                  size={16}
                  className={syncing ? "spin" : ""}
                />
              </button>
              <button
                type="button"
                className="icon-tool-button"
                aria-label="Đổi giao diện sáng tối"
                title={
                  dark
                    ? "Chuyển sang giao diện sáng"
                    : "Chuyển sang giao diện tối"
                }
                onClick={() => {
                  const next =
                    document.documentElement.classList.toggle("dark");
                  setDark(next);
                  localStorage.setItem(
                    "smartpark-theme",
                    next ? "dark" : "light",
                  );
                }}
              >
                <UiIcon name={dark ? "sun" : "moon"} size={17} />
              </button>
              <button
                type="button"
                className="notification-button"
                aria-label="Xem thông báo"
                onClick={() => setNotifications(true)}
              >
                <Asset name="IconBell" />
                {hasUnreadAlerts && (
                  <Asset name="NotificationDot" className="notification-dot" />
                )}
              </button>
              <button
                type="button"
                className="admin-chip"
                onClick={() => setAccount(true)}
              >
                <span className="avatar">
                  <Asset name="Avatar" />
                  <b>{ownerInitials.slice(0, 1)}</b>
                </span>
                <span>{ownerShortName}</span>
              </button>
            </div>
          </header>
          <main
            id="main-content"
            className={`main-content page-${pathname.slice(1) || "overview"}`}
          >
            <Outlet key={pathname + routeSearch} />
          </main>
        </div>

        {help && (
          <Dialog
            title="Trợ giúp & luồng đồng bộ"
            onClose={() => setHelp(false)}
            footer={<Button onClick={() => setHelp(false)}>Đã hiểu</Button>}
          >
            <div className="help-blocks">
              <div className="help-item">
                <strong>Đồng bộ với Khách hàng</strong>
                <p>
                  Khi bạn cập nhật bảng giá, mở/khóa bãi đỗ hoặc bảo trì chỗ đỗ,
                  ứng dụng Khách hàng tự động cập nhật theo thời gian thực.
                </p>
              </div>
              <div className="help-item">
                <strong>Đồng bộ với Nhân viên & Doanh thu</strong>
                <p>
                  Nhân viên check-in/check-out và xác nhận thu tiền mặt trên ứng
                  dụng Nhân viên. Khoản thu sẽ xuất hiện ngay tại mục Báo cáo
                  doanh thu và Tổng quan.
                </p>
              </div>
            </div>
          </Dialog>
        )}

        {notifications && (
          <Dialog
            title="Thông báo & vận hành"
            onClose={() => setNotifications(false)}
            footer={
              unreadDbNotifications.length > 0 ? (
                <Button
                  secondary
                  onClick={() =>
                    void command("apply_operation", {
                      p_operation_id: crypto.randomUUID(),
                      p_kind: "notifications.read",
                      p_payload: {},
                    })
                  }
                >
                  Đánh dấu đã đọc ({unreadDbNotifications.length})
                </Button>
              ) : (
                <Button secondary onClick={() => setNotifications(false)}>
                  Đóng
                </Button>
              )
            }
          >
            <ul className="notification-list">
              <li>
                <div className="notif-row">
                  <strong>Trạng thái vận hành hôm nay</strong>
                  <Badge tone={online ? "green" : "gray"}>
                    {online ? "Đang đồng bộ" : "Ngoại tuyến"}
                  </Badge>
                </div>
                <p>
                  {pendingCheckinCount} vé chờ vào bãi · {activeParked.length}{" "}
                  xe đang đỗ · Thu hôm nay: {money(todayRevenue)}.
                </p>
              </li>
              {overdueCount > 0 && (
                <li>
                  <div className="notif-row">
                    <strong>{overdueCount} xe đỗ quá giờ dự kiến</strong>
                    <Badge tone="amber">Cần theo dõi</Badge>
                  </div>
                  <p>
                    Nhân viên sẽ thu thêm phí quá giờ khi khách check-out tại
                    cổng.
                  </p>
                </li>
              )}
              {data.notifications.slice(0, 6).map((item) => (
                <li
                  key={item.id}
                  className={item.read ? "notif-read" : "notif-unread"}
                >
                  <div className="notif-row">
                    <strong>{item.title}</strong>
                    {!item.read && <Badge tone="blue">Mới</Badge>}
                  </div>
                  <p>{item.body}</p>
                  <small>{formatDateTime(item.createdAt)}</small>
                </li>
              ))}
              <li>
                <div className="notif-row">
                  <strong>Đồng bộ Supabase Cloud</strong>
                </div>
                <p>
                  Cập nhật gần nhất: {lastUpdated || "chưa tải được dữ liệu"}.
                </p>
              </li>
            </ul>
          </Dialog>
        )}

        {account && (
          <Dialog
            title="Tài khoản chủ bãi"
            onClose={() => setAccount(false)}
            footer={
              <div className="dialog-action-row">
                <Button
                  secondary
                  onClick={() => {
                    void refresh();
                    setAccount(false);
                  }}
                >
                  Tải lại dữ liệu
                </Button>
                <Button
                  secondary
                  onClick={() => {
                    void signOut();
                    setAccount(false);
                  }}
                >
                  Đăng xuất
                </Button>
              </div>
            }
          >
            <div className="account-summary">
              <span className="admin-initials large">{ownerInitials}</span>
              <div>
                <strong>{ownerName}</strong>
                <p>{ownerEmail || "Tài khoản chủ bãi SmartPark"}</p>
                <Badge tone="green">Chủ bãi (Owner)</Badge>
              </div>
            </div>
            <p className="account-note">
              Phạm vi quản lý: {data.lots.length} bãi đỗ ·{" "}
              {data.lots.reduce((sum, l) => sum + l.capacity, 0)} chỗ đỗ ·{" "}
              {data.staff.filter((s) => s.active).length} phân công nhân viên
              đang hoạt động. Dữ liệu chỉ thuộc các bãi do tài khoản này sở hữu.
            </p>
          </Dialog>
        )}
      </div>
    </FrameContext.Provider>
  );
}
