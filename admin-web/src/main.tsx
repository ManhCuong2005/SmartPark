import { createRoot } from "react-dom/client";
import { BrowserRouter, Route, Routes, Navigate } from "react-router-dom";
import { lazy, Suspense } from "react";
import { AdminProvider } from "./data/store";
import { Layout } from "./app/Layout";
const OverviewPage = lazy(() =>
  import("./features/parking").then((m) => ({ default: m.OverviewPage })),
);
const ParkingPage = lazy(() =>
  import("./features/parking").then((m) => ({ default: m.ParkingPage })),
);
const BookingsPage = lazy(() =>
  import("./features/operations").then((m) => ({ default: m.BookingsPage })),
);
const StaffPage = lazy(() =>
  import("./features/operations").then((m) => ({ default: m.StaffPage })),
);
const ReportsPage = lazy(() =>
  import("./features/reports-settings").then((m) => ({
    default: m.ReportsPage,
  })),
);
const SettingsPage = lazy(() =>
  import("./features/reports-settings").then((m) => ({
    default: m.SettingsPage,
  })),
);
import "./styles.css";
try {
  const theme = localStorage.getItem("smartpark-theme");
  document.documentElement.classList.toggle(
    "dark",
    theme === "dark" ||
      (!theme && window.matchMedia("(prefers-color-scheme: dark)").matches),
  );
} catch {
  /* System theme remains available without browser storage. */
}
createRoot(document.getElementById("root")!).render(
  <BrowserRouter>
    <AdminProvider>
      <Suspense
        fallback={
          <div className="auth-page" role="status">
            Đang tải màn hình…
          </div>
        }
      >
        <Routes>
          <Route element={<Layout />}>
            <Route index element={<OverviewPage />} />
            <Route path="parking" element={<ParkingPage />} />
            <Route path="bookings" element={<BookingsPage />} />
            <Route path="staff" element={<StaffPage />} />
            <Route path="reports" element={<ReportsPage />} />
            <Route path="settings" element={<SettingsPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </Suspense>
    </AdminProvider>
  </BrowserRouter>,
);
