import { createRoot } from "react-dom/client";
import { BrowserRouter, Route, Routes, Navigate } from "react-router-dom";
import { AdminProvider } from "./data/store";
import { Layout } from "./app/Layout";
import { OverviewPage, ParkingPage } from "./features/parking";
import { BookingsPage, StaffPage } from "./features/operations";
import { ReportsPage, SettingsPage } from "./features/reports-settings";
import "./styles.css";
createRoot(document.getElementById("root")!).render(
  <BrowserRouter>
    <AdminProvider>
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
    </AdminProvider>
  </BrowserRouter>,
);
