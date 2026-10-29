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
  { loggedIn = true, owner = true, conflict = false } = {},
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
