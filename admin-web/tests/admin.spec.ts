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
  { loggedIn = true, owner = true, conflict = false, staffError = "" } = {},
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
    slots: [
      {
        id: "slot-one",
        lot_id: lot,
        code: "A001",
        enabled: true,
        occupied: false,
      },
    ],
    memberships: [],
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
      calls.push({ name, params });
      if (name === "manage_staff" && staffError)
        return route.fulfill({
          status: 400,
          json: { code: "P0001", message: staffError },
        });
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
          car_rate: 15000,
          motorcycle_rate: 5000,
          free_minutes: 0,
          version: 1,
        });
        for (let i = 0; i < params.p_capacity; i++)
          raw.slots.push({
            id: params.p_id + i,
            lot_id: params.p_id,
            code: `A00${i + 1}`,
            enabled: true,
            occupied: false,
          });
      }
      if (name === "manage_slot")
        raw.slots.find((s: any) => s.id === params.p_id).enabled =
          params.p_enabled;
      if (name === "set_pricing")
        Object.assign(raw.lots[0], {
          car_rate: params.p_car,
          motorcycle_rate: params.p_motorcycle,
          free_minutes: params.p_free_minutes,
          version: 2,
        });
      if (name === "manage_staff") {
        let person = raw.profiles.find((p: any) => p.email === params.p_email);
        if (!person) {
          person = {
            id: "staff-user",
            email: params.p_email,
            name: "Nhân viên kiểm thử",
            role: "staff",
          };
          raw.profiles.push(person);
        }
        const membership = raw.memberships.find(
          (s: any) => s.user_id === person.id && s.lot_id === params.p_lot_id,
        );
        const value = {
          user_id: person.id,
          lot_id: params.p_lot_id,
          shift: params.p_shift,
          active: params.p_active,
        };
        if (membership) Object.assign(membership, value);
        else raw.memberships.push(value);
      }
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
  return { raw, calls };
}
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
  await page.getByLabel("Số vị trí", { exact: true }).fill("2");
  await page.getByRole("button", { name: "Lưu bãi đỗ", exact: true }).click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  expect(calls[0].name).toBe("manage_lot");
  expect(calls[0].params.p_capacity).toBe(2);
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

test("owner grants staff access by registered email and selected parking lot", async ({
  page,
}) => {
  const { calls } = await connect(page);
  await page.goto("/staff");
  await page
    .getByRole("button", { name: "+ Cấp quyền nhân viên", exact: true })
    .click();
  await page.getByLabel("Email nhân viên").fill("STAFF@TEST.INVALID");
  await page.getByLabel("Ca làm việc").selectOption("afternoon");
  await page
    .getByRole("button", { name: "Cấp quyền và phân công", exact: true })
    .click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  expect(calls).toEqual([
    {
      name: "manage_staff",
      params: {
        p_lot_id: lot,
        p_email: "staff@test.invalid",
        p_shift: "afternoon",
        p_active: true,
      },
    },
  ]);
  await expect(
    page.getByRole("cell", { name: "staff@test.invalid", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Đã cấp quyền nhân viên và phân công bãi.", { exact: true }),
  ).toBeVisible();
});

test("owner revokes access without changing employee or lot identity", async ({
  page,
}) => {
  const { raw, calls } = await connect(page);
  raw.profiles.push({
    id: "staff-user",
    email: "staff@test.invalid",
    name: "Nhân viên kiểm thử",
    role: "staff",
  });
  raw.memberships.push({
    user_id: "staff-user",
    lot_id: lot,
    shift: "night",
    active: true,
  });
  await page.goto("/staff");
  await page.getByRole("button", { name: "Phân công", exact: true }).click();
  await expect(page.getByLabel("Email nhân viên")).toHaveAttribute(
    "readonly",
    "",
  );
  await expect(page.getByLabel("Bãi phân công")).toBeDisabled();
  await page.getByLabel("Cho phép làm việc tại bãi này").uncheck();
  await page
    .getByRole("button", { name: "Lưu phân công", exact: true })
    .click();
  await expect(page.getByRole("dialog")).toHaveCount(0);
  expect(calls[0]).toEqual({
    name: "manage_staff",
    params: {
      p_lot_id: lot,
      p_email: "staff@test.invalid",
      p_shift: "night",
      p_active: false,
    },
  });
  await expect(page.getByText("Tạm ngưng", { exact: true })).toBeVisible();
});

for (const [error, message] of [
  [
    "USER_MUST_REGISTER_FIRST",
    "Nhân viên cần đăng ký tài khoản trong app trước khi phân công.",
  ],
  [
    "USER_EMAIL_NOT_CONFIRMED",
    "Tài khoản này chưa xác nhận email. Hãy xác nhận email trước khi cấp quyền nhân viên.",
  ],
])
  test(`staff grant keeps form open on ${error}`, async ({ page }) => {
    await connect(page, { staffError: error });
    await page.goto("/staff");
    await page
      .getByRole("button", { name: "+ Cấp quyền nhân viên", exact: true })
      .click();
    await page.getByLabel("Email nhân viên").fill("staff@test.invalid");
    await page
      .getByRole("button", { name: "Cấp quyền và phân công", exact: true })
      .click();
    await expect(page.getByRole("status")).toContainText(message);
    await expect(page.getByRole("dialog")).toBeVisible();
    await expect(
      page.getByText("Đã cấp quyền nhân viên và phân công bãi.", {
        exact: true,
      }),
    ).toHaveCount(0);
  });

test("staff grant requires an owned parking lot", async ({ page }) => {
  const { raw } = await connect(page);
  raw.lots = [];
  await page.goto("/staff");
  await expect(
    page.getByRole("button", { name: "+ Cấp quyền nhân viên", exact: true }),
  ).toBeDisabled();
  await expect(
    page.getByText(
      "Tạo bãi đỗ trước để cấp quyền nhân viên làm việc tại bãi đó.",
    ),
  ).toBeVisible();
});
for (const width of [390, 768, 1440])
  for (const route of [
    "/",
    "/parking",
    "/bookings",
    "/staff",
    "/reports",
    "/settings",
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
    id: "staff-collector",
    email: "staff@test.invalid",
    name: "Trần Minh Hà",
    role: "staff",
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
    { id: "v-car", user_id: actor, label: "Mazda 3", plate: "43A12345", kind: "car" },
    { id: "v-moto", user_id: actor, label: "Honda AirBlade", plate: "43C199999", kind: "motorcycle" },
  );
  raw.bookings[0].vehicle_id = "v-car";
  raw.payments[0].received_by = "staff-collector";
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
    received_by: "staff-collector",
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
    received_by: "staff-collector",
    paid_at: "2026-09-15T13:00:00",
  });

  await page.goto("/reports");
  await expect(page.getByText("40.000đ", { exact: true }).first()).toBeVisible();
  await expect(page.getByText("Ô tô: 1 · Xe máy: 1")).toBeVisible();

  // Click lot card to filter to Bãi thứ hai
  await page.locator("button.rank-card", { hasText: "Bãi thứ hai" }).click();
  await expect(page.getByText("10.000đ", { exact: true }).first()).toBeVisible();
  await page.getByRole("button", { name: "Bỏ lọc bãi" }).click();
  await expect(page.getByText("40.000đ", { exact: true }).first()).toBeVisible();

  // Switch to "Tất cả" period to include 2026-09 historical payment
  await page.getByRole("tab", { name: "Tất cả" }).click();
  await expect(page.getByText("85.000đ", { exact: true }).first()).toBeVisible();

  // Back to "Theo tháng" and inspect an empty month -> guidance banner recovers cleanly
  await page.getByRole("tab", { name: "Theo tháng" }).click();
  await page.getByLabel("Tháng báo cáo").fill("2025-01");
  await expect(page.getByText(/Chưa có khoản thu nào trong tháng 1\/2025/)).toBeVisible();
  await page.getByRole("button", { name: /Xem tháng/ }).click();
  await expect(page.getByText("40.000đ", { exact: true }).first()).toBeVisible();

  // Search ledger and open receipt dialog
  await page.getByPlaceholder("Tìm biển số, khách hàng, người thu...").fill("43C199999");
  await page.getByRole("button", { name: "Chi tiết" }).click();
  await expect(page.getByRole("dialog", { name: "Chi tiết biên lai thu tiền" })).toBeVisible();
  await expect(page.getByRole("dialog").getByText("Trần Minh Hà")).toBeVisible();
  await page.getByRole("dialog").getByRole("button", { name: "Đóng", exact: true }).click();
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
    received_by: "staff-collector",
    paid_at: `${today}T13:00:00`,
  });
  await page.getByRole("button", { name: "Làm mới" }).click();
  await expect(page.getByText("90.000đ", { exact: true }).first()).toBeVisible();
  await expect(page.getByText("43A88888")).toBeVisible();
});
