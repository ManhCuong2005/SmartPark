import { test, expect } from "@playwright/test";
import type { Page } from "@playwright/test";

const actor = "10000000-0000-0000-0000-000000000004",
  lot = "20000000-0000-0000-0000-000000000001";
const today = new Date().toLocaleDateString("en-CA");
function session() {
  const exp = Math.floor(Date.now() / 1000) + 3600;
  const encode = (value: unknown) =>
    Buffer.from(JSON.stringify(value)).toString("base64url");
  return {
    access_token: `${encode({ alg: "HS256" })}.${encode({ sub: actor, exp, role: "authenticated" })}.test`,
    refresh_token: "test-refresh",
    expires_in: 3600,
    expires_at: exp,
    token_type: "bearer",
    user: {
      id: actor,
      aud: "authenticated",
      email: "owner@test.invalid",
      created_at: new Date().toISOString(),
      app_metadata: {},
      user_metadata: {},
    },
  };
}
async function connect(
  page: Page,
  {
    loggedIn = true,
    owner = true,
    conflict = false,
    loseAdjustmentAck = false,
  } = {},
) {
  const raw: Record<string, any> = {
    server_time: new Date().toISOString(),
    profiles: [
      {
        id: actor,
        email: "owner@test.invalid",
        name: "Chủ bãi thử nghiệm",
        role: owner ? "owner" : "customer",
      },
    ],
    lots: [
      {
        id: lot,
        owner_id: actor,
        name: "Bãi kiểm thử",
        area: "Địa chỉ kiểm thử",
        enabled: true,
        car_capacity: 1,
        motorcycle_capacity: 1,
        car_rate: 15000,
        motorcycle_rate: 5000,
        free_minutes: 10,
        version: 1,
        latitude: 16.05,
        longitude: 108.2,
      },
      {
        id: "other-lot",
        owner_id: "other-owner",
        name: "Bãi của người khác",
        enabled: true,
        car_rate: 20000,
        motorcycle_rate: 5000,
        free_minutes: 0,
        version: 1,
      },
    ],
    capacities: [
      { lot_id: lot, kind: "car", capacity: 1, remaining: 1 },
      { lot_id: lot, kind: "motorcycle", capacity: 1, remaining: 1 },
    ],
    reports: [],
    report_events: [],
    slots: [
      {
        id: "slot-one",
        lot_id: lot,
        code: "A001",
        enabled: true,
        occupied: false,
      },
    ],
    vehicles: [],
    notifications: [],
    bookings: [
      {
        id: "60000000-0000-0000-0000-000000000001",
        customer_id: actor,
        lot_id: lot,
        plate: "43A12345",
        starts_at: `${today}T08:00:00`,
        ends_at: `${today}T10:00:00`,
        status: "completed",
        checked_in_at: `${today}T08:00:00`,
        checked_out_at: `${today}T10:00:00`,
        amount: 30000,
        version: 3,
      },
    ],
    payments: [
      {
        id: "payment",
        booking_id: "60000000-0000-0000-0000-000000000001",
        amount: 30000,
        paid_at: `${today}T10:00:00`,
      },
    ],
  };
  const walletAccount = {
    id: "wallet-customer",
    email: "customer@test.invalid",
    name: "Khách kiểm thử",
    role: "customer",
    balance: 100000,
  };
  const adjustments: Record<string, any>[] = [];
  const calls: { name: string; params: Record<string, any> }[] = [];
  await page.routeWebSocket(
    "wss://odpxmbkzdqutxitsdfaw.supabase.co/**",
    (socket) => socket.close(),
  );
  await page.route(
    "https://odpxmbkzdqutxitsdfaw.supabase.co/**",
    async (route) => {
      const url = new URL(route.request().url()),
        name = url.pathname.split("/").pop()!,
        params = route.request().postDataJSON() ?? {};
      if (url.pathname === "/auth/v1/token")
        return route.fulfill({ json: session() });
      if (name === "park_snapshot") return route.fulfill({ json: raw });
      if (name === "admin_wallet_accounts") {
        const q = String(params.p_query ?? "").toLowerCase();
        const accounts = `${walletAccount.email} ${walletAccount.name}`
          .toLowerCase()
          .includes(q)
          ? [walletAccount]
          : [];
        return route.fulfill({
          json: { accounts, total: accounts.length, adjustments },
        });
      }
      calls.push({ name, params });
      if (name === "admin_adjust_wallet") {
        let receipt = adjustments.find((a) => a.id === params.p_operation_id);
        if (!receipt) {
          if (walletAccount.balance + params.p_amount < 0)
            return route.fulfill({
              status: 400,
              json: { code: "P0001", message: "INSUFFICIENT_BALANCE" },
            });
          walletAccount.balance += params.p_amount;
          receipt = {
            id: params.p_operation_id,
            customer_id: walletAccount.id,
            customer_email: walletAccount.email,
            actor_id: actor,
            actor_email: "owner@test.invalid",
            amount: params.p_amount,
            reason: params.p_reason,
            balance_after: walletAccount.balance,
            created_at: new Date().toISOString(),
          };
          adjustments.unshift(receipt);
          if (loseAdjustmentAck) {
            loseAdjustmentAck = false;
            return route.abort("failed");
          }
        }
        return route.fulfill({ json: receipt });
      }
      if (conflict)
        return route.fulfill({
          status: 400,
          json: { code: "P0001", message: "VERSION_CONFLICT" },
        });
      if (name === "manage_lot") {
        raw.lots.push({
          id: params.p_id,
          owner_id: actor,
          name: params.p_name,
          area: params.p_area,
          enabled: params.p_enabled,
          car_capacity: params.p_car_capacity,
          motorcycle_capacity: params.p_motorcycle_capacity,
          car_rate: 15000,
          motorcycle_rate: 5000,
          free_minutes: 0,
          version: 1,
        });
        raw.capacities.push(
          {
            lot_id: params.p_id,
            kind: "car",
            capacity: params.p_car_capacity,
            remaining: params.p_car_capacity,
          },
          {
            lot_id: params.p_id,
            kind: "motorcycle",
            capacity: params.p_motorcycle_capacity,
            remaining: params.p_motorcycle_capacity,
          },
        );
      }
      if (
        name === "apply_operation" &&
        String(params.p_kind).startsWith("report.")
      ) {
        const r = raw.reports.find(
          (r: any) => r.id === params.p_payload.report_id,
        );
        r.status =
          params.p_kind === "report.request_move"
            ? "move_requested"
            : params.p_payload.status;
        r.version++;
        raw.report_events.push({
          id: crypto.randomUUID(),
          report_id: r.id,
          status: r.status,
          created_at: new Date().toISOString(),
          note: "",
        });
      }
      if (name === "set_pricing")
        Object.assign(raw.lots[0], {
          car_rate: params.p_car,
          motorcycle_rate: params.p_motorcycle,
          free_minutes: params.p_free_minutes,
          version: 2,
        });
      return route.fulfill({ json: null });
    },
  );
  if (loggedIn)
    await page.addInitScript(
      ({ key, value }) => localStorage.setItem(key, JSON.stringify(value)),
      {
        key: "sb-odpxmbkzdqutxitsdfaw-auth-token",
        value: session(),
      },
    );
  return { raw, calls, walletAccount, adjustments };
}
test("admin credits and debits wallets with a reason and audit history, without personnel menus", async ({
  page,
}) => {
  const { walletAccount, adjustments } = await connect(page);
  await page.goto("/wallets");
  await expect(
    page.getByRole("heading", { name: "Số dư tài khoản", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("link", { name: "Nhân viên", exact: true }),
  ).toHaveCount(0);
  await page
    .getByPlaceholder("Tìm tên hoặc email tài khoản")
    .fill("customer@test.invalid");
  await expect(
    page.locator("table").first().getByText("customer@test.invalid"),
  ).toBeVisible();
  await page.getByRole("button", { name: "Cộng tiền", exact: true }).click();
  await page.getByLabel("Số tiền (đ)", { exact: true }).fill("2000000");
  await page
    .getByLabel("Lý do điều chỉnh", { exact: true })
    .fill("Cộng số dư kiểm thử");
  for (const width of [390, 1440]) {
    await page.setViewportSize({ width, height: 950 });
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth > window.innerWidth + 1,
      ),
    ).toBe(false);
    await page.screenshot({
      path: `../.smartpark/ui-review/wallet-adjustment-${width}.png`,
      fullPage: true,
    });
  }
  await page
    .getByRole("button", { name: "Xác nhận cộng tiền", exact: true })
    .click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  expect(walletAccount.balance).toBe(2100000);
  await expect(
    page
      .locator("table")
      .last()
      .getByText("Cộng số dư kiểm thử", { exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Trừ tiền", exact: true }).click();
  await page.getByLabel("Số tiền (đ)", { exact: true }).fill("100000");
  await page
    .getByLabel("Lý do điều chỉnh", { exact: true })
    .fill("Điều chỉnh giảm kiểm thử");
  await page
    .getByRole("button", { name: "Xác nhận trừ tiền", exact: true })
    .click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  expect(walletAccount.balance).toBe(2000000);
  expect(adjustments).toHaveLength(2);
});

test("wallet rejects overdraft and retains editable correction", async ({
  page,
}) => {
  const { walletAccount, adjustments } = await connect(page);
  await page.goto("/wallets");
  await page.getByRole("button", { name: "Trừ tiền", exact: true }).click();
  await page.getByLabel("Số tiền (đ)", { exact: true }).fill("100001");
  await page
    .getByLabel("Lý do điều chỉnh", { exact: true })
    .fill("Kiểm thử thiếu số dư");
  await page
    .getByRole("button", { name: "Xác nhận trừ tiền", exact: true })
    .click();
  await expect(page.getByRole("alert")).toContainText(
    "Số dư hiện tại không đủ",
  );
  await expect(page.getByLabel("Số tiền (đ)", { exact: true })).toBeEnabled();
  expect(walletAccount.balance).toBe(100000);
  expect(adjustments).toHaveLength(0);
});

test("wallet restores an unknown correction after reload and replays the same ID", async ({
  page,
}) => {
  const { calls, walletAccount, adjustments } = await connect(page, {
    loseAdjustmentAck: true,
  });
  await page.goto("/wallets");
  await page.getByRole("button", { name: "Cộng tiền", exact: true }).click();
  await page.getByLabel("Số tiền (đ)", { exact: true }).fill("2000000");
  await page
    .getByLabel("Lý do điều chỉnh", { exact: true })
    .fill("Kiểm thử mất phản hồi");
  await page
    .getByRole("button", { name: "Xác nhận cộng tiền", exact: true })
    .click();
  await expect(
    page.getByRole("button", { name: "Thử lại cùng giao dịch", exact: true }),
  ).toBeVisible();
  await page.reload();
  await expect(page.getByLabel("Số tiền (đ)", { exact: true })).toBeDisabled();
  await page
    .getByRole("button", { name: "Thử lại cùng giao dịch", exact: true })
    .click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  expect(walletAccount.balance).toBe(2100000);
  expect(adjustments).toHaveLength(1);
  const writes = calls.filter((c) => c.name === "admin_adjust_wallet");
  expect(writes).toHaveLength(2);
  expect(writes[0].params).toEqual(writes[1].params);
});

test("requires real authentication before showing admin pages", async ({
  page,
}) => {
  const { calls } = await connect(page, { loggedIn: false });
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Đăng nhập chủ bãi" }),
  ).toBeVisible();
  await page.getByLabel("Email", { exact: true }).fill("owner@test.invalid");
  await page.getByLabel("Mật khẩu", { exact: true }).fill("test-password");
  await page.getByRole("button", { name: "Đăng nhập", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Tổng quan hệ thống" }),
  ).toBeVisible();
  expect(calls).toHaveLength(0);
});
test("customer role cannot open owner dashboard", async ({ page }) => {
  await connect(page, { owner: false });
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Tổng quan hệ thống" }),
  ).toHaveCount(0);
  await expect(
    page.getByRole("button", { name: "Đăng xuất", exact: true }),
  ).toBeVisible();
});
test("dashboard derives receipts and scopes lots to the current owner", async ({
  page,
}) => {
  await connect(page);
  await page.goto("/");
  await expect(page.getByText("30.000đ", { exact: true })).toBeVisible();
  await expect(page.getByText("Bãi của người khác")).toHaveCount(0);
  await expect(page.getByText("Supabase · đã kết nối")).toBeVisible();
});
test("lot form sends versioned RPC and waits for cloud response", async ({
  page,
}) => {
  const { calls } = await connect(page);
  await page.goto("/parking");
  await page.getByRole("button", { name: "+ Thêm bãi đỗ" }).click();
  await page.getByLabel("Tên bãi", { exact: true }).fill("Bãi mới");
  await page.getByLabel("Địa chỉ", { exact: true }).fill("Địa chỉ mới");
  await page.getByLabel("Sức chứa ô tô", { exact: true }).fill("2");
  await page.getByRole("button", { name: "Lưu bãi đỗ", exact: true }).click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  expect(calls[0].name).toBe("manage_lot");
  expect(calls[0].params.p_car_capacity).toBe(2);
  expect(calls[0].params.p_motorcycle_capacity).toBe(16);
  await expect(
    page.getByRole("cell", { name: "Bãi mới", exact: true }),
  ).toBeVisible();
});
test("price updates carry expected version and conflicts never report success", async ({
  page,
}) => {
  const { calls } = await connect(page, { conflict: true });
  await page.goto("/settings");
  await page.getByLabel("Phí ô tô / giờ").fill("20000");
  await page.getByRole("button", { name: "Lưu thay đổi", exact: true }).click();
  await expect(
    page.getByText(
      "Dữ liệu đã thay đổi trên thiết bị khác. Tải lại trước khi sửa.",
    ),
  ).toBeVisible();
  expect(calls[0].params.p_expected_version).toBe(1);
  await expect(page.getByText("Đã lưu bảng giá trên Supabase.")).toHaveCount(0);
});

for (const width of [390, 768, 1440])
  for (const route of [
    "/",
    "/parking",
    "/bookings",
    "/wallets",
    "/reports",
    "/settings",
    "/incidents",
  ]) {
    test(`${route} responsive at ${width}`, async ({ page }) => {
      await connect(page);
      await page.setViewportSize({ width, height: 950 });
      await page.goto(route);
      await expect(page.locator("main h1")).toBeVisible();
      const overflow = await page.evaluate(
        () => document.documentElement.scrollWidth > window.innerWidth + 1,
      );
      expect(overflow).toBeFalsy();
    });
  }
test("dark mode remains usable and captures review artifacts", async ({
  page,
}) => {
  await connect(page);
  await page.goto("/");
  await page.getByRole("button", { name: "Đổi giao diện sáng tối" }).click();
  await expect(page.locator("html")).toHaveClass(/dark/);
  await page.screenshot({
    path: "test-results/admin-dark.png",
    fullPage: true,
  });
  await page.getByRole("button", { name: "Đổi giao diện sáng tối" }).click();
  await page.screenshot({
    path: "test-results/admin-light.png",
    fullPage: true,
  });
});

test("reports supports period switching, lot filtering, receipt modal, CSV export, and real-time sync", async ({
  page,
}) => {
  const { raw } = await connect(page);
  const lot2 = "20000000-0000-0000-0000-000000000002";
  raw.profiles.push({
    id: "historical-collector",
    email: "staff@test.invalid",
    name: "Trần Minh Hà",
    role: "customer",
  });
  raw.lots.push({
    id: lot2,
    owner_id: actor,
    name: "Bãi thứ hai",
    area: "Quận Hải Châu",
    enabled: true,
    car_rate: 20000,
    motorcycle_rate: 5000,
    free_minutes: 0,
    version: 1,
  });
  raw.vehicles.push(
    {
      id: "v-car",
      user_id: actor,
      label: "Mazda 3",
      plate: "43A12345",
      kind: "car",
    },
    {
      id: "v-moto",
      user_id: actor,
      label: "Honda AirBlade",
      plate: "43C199999",
      kind: "motorcycle",
    },
  );
  raw.bookings[0].vehicle_id = "v-car";
  raw.payments[0].received_by = "historical-collector";
  raw.payments[0].method = "cash";

  // Same-day motorcycle checkout at lot2
  raw.bookings.push({
    id: "60000000-0000-0000-0000-000000000002",
    customer_id: actor,
    vehicle_id: "v-moto",
    lot_id: lot2,
    plate: "43C199999",
    starts_at: `${today}T07:00:00`,
    ends_at: `${today}T09:00:00`,
    status: "completed",
    checked_in_at: `${today}T07:00:00`,
    checked_out_at: `${today}T09:00:00`,
    hourly_rate: 5000,
    free_minutes: 0,
    amount: 10000,
    version: 3,
  });
  raw.payments.push({
    id: "payment-moto",
    booking_id: "60000000-0000-0000-0000-000000000002",
    amount: 10000,
    method: "cash",
    received_by: "historical-collector",
    paid_at: `${today}T09:00:00`,
  });

  // Historical payment in 2026-09 (outside current month unless switching period/month)
  raw.bookings.push({
    id: "60000000-0000-0000-0000-000000000003",
    customer_id: actor,
    vehicle_id: "v-car",
    lot_id: lot,
    plate: "43A12345",
    starts_at: "2026-09-15T10:00:00",
    ends_at: "2026-09-15T13:00:00",
    status: "completed",
    checked_in_at: "2026-09-15T10:00:00",
    checked_out_at: "2026-09-15T13:00:00",
    hourly_rate: 15000,
    free_minutes: 0,
    amount: 45000,
    version: 3,
  });
  raw.payments.push({
    id: "payment-hist",
    booking_id: "60000000-0000-0000-0000-000000000003",
    amount: 45000,
    method: "cash",
    received_by: "historical-collector",
    paid_at: "2026-09-15T13:00:00",
  });

  await page.goto("/reports");
  await expect(
    page.getByText("40.000đ", { exact: true }).first(),
  ).toBeVisible();
  await expect(page.getByText("Ô tô: 1 · Xe máy: 1")).toBeVisible();

  // Click lot card to filter to Bãi thứ hai
  await page.locator("button.rank-card", { hasText: "Bãi thứ hai" }).click();
  await expect(
    page.getByText("10.000đ", { exact: true }).first(),
  ).toBeVisible();
  await page.getByRole("button", { name: "Bỏ lọc bãi" }).click();
  await expect(
    page.getByText("40.000đ", { exact: true }).first(),
  ).toBeVisible();

  // Switch to "Tất cả" period to include 2026-09 historical payment
  await page.getByRole("tab", { name: "Tất cả" }).click();
  await expect(
    page.getByText("85.000đ", { exact: true }).first(),
  ).toBeVisible();

  // Back to "Theo tháng" and inspect an empty month -> guidance banner recovers cleanly
  await page.getByRole("tab", { name: "Theo tháng" }).click();
  await page.getByLabel("Tháng báo cáo").fill("2025-01");
  await expect(
    page.getByText(/Chưa có khoản thu nào trong tháng 1\/2025/),
  ).toBeVisible();
  await page.getByRole("button", { name: /Xem tháng/ }).click();
  await expect(
    page.getByText("40.000đ", { exact: true }).first(),
  ).toBeVisible();

  // Search ledger and open receipt dialog
  await page
    .getByPlaceholder("Tìm biển số, khách hàng, người thu...")
    .fill("43C199999");
  await page.getByRole("button", { name: "Chi tiết" }).click();
  await expect(
    page.getByRole("dialog", { name: "Chi tiết biên lai thu tiền" }),
  ).toBeVisible();
  await expect(
    page.getByRole("dialog").getByText("Trần Minh Hà"),
  ).toBeVisible();
  await page
    .getByRole("dialog")
    .getByRole("button", { name: "Đóng", exact: true })
    .click();
  await page.getByPlaceholder("Tìm biển số, khách hàng, người thu...").fill("");

  // Export CSV triggers download and notice
  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "Xuất báo cáo" }).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toContain("smartpark-doanh-thu-");
  await expect(page.getByText("Đã xuất 2 giao dịch ra tệp CSV.")).toBeVisible();

  // Simulate new Staff check-out payment synced via refresh
  raw.bookings.push({
    id: "60000000-0000-0000-0000-000000000004",
    customer_id: actor,
    vehicle_id: "v-car",
    lot_id: lot,
    plate: "43A88888",
    starts_at: `${today}T11:00:00`,
    ends_at: `${today}T13:00:00`,
    status: "completed",
    checked_in_at: `${today}T11:00:00`,
    checked_out_at: `${today}T13:00:00`,
    hourly_rate: 15000,
    free_minutes: 0,
    amount: 50000,
    version: 3,
  });
  raw.payments.push({
    id: "payment-live",
    booking_id: "60000000-0000-0000-0000-000000000004",
    amount: 50000,
    method: "cash",
    received_by: "historical-collector",
    paid_at: `${today}T13:00:00`,
  });
  await page.getByRole("button", { name: "Làm mới" }).click();
  await expect(
    page.getByText("90.000đ", { exact: true }).first(),
  ).toBeVisible();
  await expect(page.getByText("43A88888")).toBeVisible();
});

test("owner requests a move, handles the incident and sees processing history", async ({
  page,
}) => {
  const { raw, calls } = await connect(page);
  raw.reports.push({
    id: "report-one",
    lot_id: lot,
    plate: "43A12345",
    description: "Chắn lối đi",
    status: "open",
    version: 1,
    created_at: new Date().toISOString(),
  });
  raw.reports.push({
    id: "foreign-report",
    lot_id: "other-lot",
    plate: "43A99999",
    description: "Không được xem",
    status: "open",
    version: 1,
  });
  await page.goto("/incidents");
  await expect(page.getByText("Chắn lối đi", { exact: true })).toBeVisible();
  await expect(page.getByText("Không được xem", { exact: true })).toHaveCount(
    0,
  );
  for (const width of [390, 1440]) {
    await page.setViewportSize({ width, height: 950 });
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth > window.innerWidth + 1,
      ),
    ).toBe(false);
    await page
      .getByRole("button", { name: "Yêu cầu chủ xe di chuyển" })
      .click({ trial: true });
    await page.screenshot({
      animations: "disabled",
      path: `../.smartpark/ui-review/incidents-${width}.png`,
      fullPage: true,
    });
  }
  await page.getByRole("button", { name: "Yêu cầu chủ xe di chuyển" }).click();
  await expect(
    page.getByRole("heading", { name: "43A12345 · Đã yêu cầu di chuyển" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Bắt đầu xử lý" }).click();
  await expect(
    page.getByRole("heading", { name: "43A12345 · Đang xử lý" }),
  ).toBeVisible();
  await page
    .getByRole("button", { name: "Đã giải quyết", exact: true })
    .click();
  await expect(
    page.getByRole("heading", { name: "43A12345 · Đã giải quyết" }),
  ).toBeVisible();
  await page.getByText("Lịch sử xử lý", { exact: true }).click();
  await expect(
    page.getByRole("listitem").filter({ hasText: "Đang xử lý" }),
  ).toBeVisible();
  const commands = calls.filter((c) => c.name === "apply_operation");
  expect(commands.map((c) => c.params.p_kind)).toEqual([
    "report.request_move",
    "report.progress",
    "report.progress",
  ]);
  expect(commands.map((c) => c.params.p_payload.expected_version)).toEqual([
    1, 2, 3,
  ]);
});

test("capacity reduction rejection keeps the form open and explains the conflicting commitments", async ({
  page,
}) => {
  await connect(page);
  await page.route("**/rest/v1/rpc/manage_lot", (route) =>
    route.fulfill({
      status: 400,
      json: {
        code: "P0001",
        message: "CAPACITY_CONFLICT",
        details: "car: cần tối thiểu 1 chỗ cho vé còn hiệu lực",
      },
    }),
  );
  await page.goto("/parking");
  await page.getByRole("button", { name: "Sửa", exact: true }).first().click();
  await page.getByLabel("Sức chứa ô tô", { exact: true }).fill("0");
  await page.getByRole("button", { name: "Lưu bãi đỗ", exact: true }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await expect(
    page.getByText(/Không thể giảm sức chứa: car: cần tối thiểu 1 chỗ/),
  ).toBeVisible();
});
