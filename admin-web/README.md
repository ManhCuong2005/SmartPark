# SmartPark Admin Web

React + TypeScript + Vite implementation of all six Admin frames in the SmartPark Figma file. This local project sits beside the existing Customer and Staff Flutter apps.

## Run on Windows

```powershell
cd D:\LapTrinhDaNenTang\SmartPark\admin-web
npm.cmd install
npm.cmd run dev
```

Open http://127.0.0.1:5173. Dependencies are already installed on this machine. `npm.cmd` avoids Windows PowerShell's npm.ps1 execution-policy restriction. Node.js 24 was used for validation; Vite 8 requires a supported modern Node release.

No login is required for this UI demo. The blue **Dữ liệu demo** label appears on every screen.

## Screens and routes

| Figma frame | Screen | Route |
|---|---|---|
| 30:5 | Tổng quan hệ thống | `/` |
| 30:177 | Quản lý bãi đỗ | `/parking` |
| 30:382 | Quản lý đặt chỗ | `/bookings` |
| 30:553 | Quản lý nhân viên | `/staff` |
| 30:735 | Báo cáo & doanh thu | `/reports` |
| 30:894 | Cài đặt & giá vé | `/settings` |

## Implemented interactions

- Global search across parking lots, tickets and staff; deep links to filtered tables.
- Search, status filtering and pagination of parking lots; add/edit capacity, occupancy, location and enabled status.
- Booking search/status/date filters, ticket details, local cancellation and CSV export of filtered results.
- Staff search, pagination, add/edit, parking assignment and shift/status assignment.
- Sample revenue and payment breakdown charts, tooltips and an explicitly named demo report CSV.
- Independent per-lot pricing, booking rule switches, estimated hourly fee and persistent local changes.
- Responsive sidebar/drawer, scrollable tables, dialogs with keyboard focus, notification/help/account dialogs, form validation and empty states.
- Reset demo data from the **Quản trị** button in the top bar.

## Data boundaries

The seed includes 8 parking lots, 48 bookings and 16 staff, with sample date **22/10/2026** to match Figma. Aggregate revenue charts are a fixed illustrative dataset, not derived from real payments or the 48 demonstration booking rows.

Changes are saved in this browser's `localStorage` under `smartpark-admin-demo-v1`; Customer and Staff Flutter apps do not share this storage. No Firebase, real login, server authorization, payment gateway, QR verification, gate control, scheduled backup or email delivery is connected. Price/rule changes never apply to a real parking system.

## Source structure

```text
src/
  app/Layout.tsx              Shared sidebar, topbar and global search
  components/ui.tsx           Cards, metrics, assets, charts, dialogs and tables
  data/mock.ts                Typed models and initial sample records
  data/store.tsx              Local state, persistence and CSV download
  features/parking.tsx        Overview and parking management
  features/operations.tsx     Bookings and staff management
  features/reports-settings.tsx
  styles.css                  Shared design tokens and responsive layouts
public/assets/
  figma/                      114 original SVG exports from Figma MCP
  fonts/                      Inter and its OFL license
```

## Build and verification

```powershell
npm.cmd run build
npm.cmd test
npm.cmd run preview
```

Production output: `dist/`. React Router uses browser history; production hosting must fall back to `index.html` for app routes. Vite development and preview servers already support this. Browser tests use installed Google Chrome through Playwright, and start/stop their own local Vite server.

30 browser tests cover all six screens at 1440, 1280, 768 and 390 px, static asset load/geometry, overflow, and primary local workflows. TypeScript checks are part of the build.

[Visual comparison with overlay](docs/visual-review.html) — open locally in a browser. Six Figma screenshots and six actual browser renders are saved alongside the high fidelity design contexts in `docs/`. Reference screenshots are review artifacts only, not runtime UI assets. Native date picker appearance, editable controls, pagination and responsive reflow may differ from Figma. No pixel-perfect claim is made.
