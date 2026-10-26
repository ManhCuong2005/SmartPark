import { useState } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { Asset, Dialog, Button, FrameContext } from "../components/ui";
import { useAdmin } from "../data/store";
export const nav = [
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
    { data, reset, notice } = useAdmin();
  const [mobile, setMobile] = useState(false),
    [help, setHelp] = useState(false),
    [notifications, setNotifications] = useState(false),
    [account, setAccount] = useState(false),
    [search, setSearch] = useState("");
  const frame = nav.find((n) => n.path === pathname)?.frame ?? "30:5";
  const q = search.toLocaleLowerCase("vi").trim();
  const hits = q
    ? [
        ...data.lots
          .filter((l) =>
            (l.name + " " + l.area).toLocaleLowerCase("vi").includes(q),
          )
          .slice(0, 3)
          .map((l) => ({
            label: l.name,
            kind: "Bãi đỗ",
            path: "/parking?q=" + encodeURIComponent(l.name),
          })),
        ...data.bookings
          .filter((b) =>
            (b.id + " " + b.customer + " " + b.plate)
              .toLocaleLowerCase("vi")
              .includes(q),
          )
          .slice(0, 3)
          .map((b) => ({
            label: `${b.id} · ${b.customer}`,
            kind: "Đặt chỗ",
            path: "/bookings?q=" + encodeURIComponent(b.id),
          })),
        ...data.staff
          .filter((s) =>
            (s.name + " " + s.id).toLocaleLowerCase("vi").includes(q),
          )
          .slice(0, 3)
          .map((s) => ({
            label: s.name,
            kind: "Nhân viên",
            path: "/staff?q=" + encodeURIComponent(s.name),
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
            <button className="support" onClick={() => setHelp(true)}>
              <span>
                <Asset name="IconHelp" />
                <strong>Trợ giúp quản lý</strong>
              </span>
              <small>
                Hỗ trợ vận hành bãi đỗ
                <br />
                và quản lý hệ thống.
              </small>
            </button>
            <button
              className="sidebar-account"
              onClick={() => setAccount(true)}
            >
              <span className="admin-initials">AD</span>
              <span>
                <strong>Admin SmartPark</strong>
                <small>Quản trị viên</small>
              </span>
            </button>
          </div>
        </aside>
        <div className="workspace">
          <header className="topbar">
            <button
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
                placeholder="Tìm bãi đỗ, đặt chỗ, nhân viên..."
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
                    <p>Không tìm thấy kết quả.</p>
                  )}
                </div>
              )}
            </div>
            <div className="topbar-actions">
              <span className="demo-label">Dữ liệu demo</span>
              <button
                className="notification-button"
                aria-label="Xem thông báo"
                onClick={() => setNotifications(true)}
              >
                <Asset name="IconBell" />
                <Asset name="NotificationDot" className="notification-dot" />
              </button>
              <button className="admin-chip" onClick={() => setAccount(true)}>
                <span className="avatar">
                  <Asset name="Avatar" />
                  <b>A</b>
                </span>
                <span>Quản trị</span>
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
            title="Trợ giúp quản lý"
            onClose={() => setHelp(false)}
            footer={<Button onClick={() => setHelp(false)}>Đã hiểu</Button>}
          >
            <p>
              Đây là giao diện Admin SmartPark với dữ liệu demo lưu trên trình
              duyệt. Bạn có thể thêm bãi đỗ, phân ca nhân viên, tra cứu đơn và
              xuất CSV.
            </p>
            <p>
              Các cổng thanh toán, Firebase, camera/QR và dữ liệu vận hành thực
              tế chưa được kết nối. Thay đổi quy tắc chỉ cập nhật mô phỏng
              local.
            </p>
          </Dialog>
        )}
        {notifications && (
          <Dialog
            title="Thông báo hệ thống"
            onClose={() => setNotifications(false)}
          >
            <ul className="notification-list">
              <li>
                <strong>02 lượt đặt chỗ sắp đến</strong>
                <p>
                  Kiểm tra bãi xe Trung tâm và phân công nhân viên trong ca
                  demo.
                </p>
              </li>
              <li>
                <strong>Dữ liệu đang ở chế độ mô phỏng</strong>
                <p>
                  Không có giao dịch thanh toán hoặc cập nhật từ thiết bị thực.
                </p>
              </li>
            </ul>
          </Dialog>
        )}
        {account && (
          <Dialog
            title="Tài khoản quản trị demo"
            onClose={() => setAccount(false)}
            footer={
              <Button
                secondary
                onClick={() => {
                  reset();
                  setAccount(false);
                  navigate("/");
                }}
              >
                Khôi phục dữ liệu demo
              </Button>
            }
          >
            <p>
              <strong>Admin SmartPark</strong> · Quản trị viên
            </p>
            <p>
              Chưa kết nối xác thực hoặc phân quyền backend. Bản demo không yêu
              cầu đăng nhập.
            </p>
            <Button
              secondary
              onClick={() => {
                notice(
                  "Chế độ demo chưa kết nối đăng nhập hoặc đăng xuất thực tế.",
                );
                setAccount(false);
              }}
            >
              Thông tin phiên demo
            </Button>
          </Dialog>
        )}
      </div>
    </FrameContext.Provider>
  );
}
