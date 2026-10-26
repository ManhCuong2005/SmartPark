import { test, expect } from "@playwright/test";
import fs from "node:fs";
const routes = [
  ["overview", "/", "Tổng quan hệ thống"],
  ["parking", "/parking", "Quản lý bãi đỗ"],
  ["bookings", "/bookings", "Quản lý đặt chỗ"],
  ["staff", "/staff", "Quản lý nhân viên"],
  ["reports", "/reports", "Báo cáo & doanh thu"],
  ["settings", "/settings", "Cài đặt & giá vé"],
];
for (const width of [1440, 1280, 768, 390])
  for (const [slug, route, title] of routes) {
    test(`${slug} renders without overflow or asset errors at ${width}`, async ({
      page,
    }) => {
      const errors: string[] = [];
      page.on("pageerror", (e) => errors.push(e.message));
      page.on("response", (r) => {
        if (
          r.status() >= 400 &&
          new URL(r.url()).origin === "http://127.0.0.1:5173"
        )
          errors.push(`${r.status()} ${r.url()}`);
      });
      await page.setViewportSize({ width, height: 900 });
      await page.goto(route);
      await expect(
        page.getByRole("heading", { name: title, exact: true, level: 1 }),
      ).toBeVisible();
      await page.evaluate(() => document.fonts.ready);
      await page
        .locator("img")
        .evaluateAll((imgs) =>
          Promise.all(imgs.map((i) => (i as HTMLImageElement).decode())),
        );
      expect(errors).toEqual([]);
      expect(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= window.innerWidth,
        ),
      ).toBe(true);
      const assets = await page
        .locator(".sidebar img,.main-content img,.topbar img")
        .evaluateAll((imgs) =>
          imgs.map((i) => {
            const e = i as HTMLImageElement,
              r = e.getBoundingClientRect();
            return {
              src: e.getAttribute("src"),
              loaded: e.complete && e.naturalWidth > 0,
              width: r.width,
              height: r.height,
              expectedWidth: e.width,
              expectedHeight: e.height,
            };
          }),
        );
      for (const a of assets) {
        expect(a.loaded, a.src ?? "asset").toBe(true);
        expect(a.width, a.src ?? "asset").toBeCloseTo(a.expectedWidth, 1);
        expect(a.height, a.src ?? "asset").toBeCloseTo(a.expectedHeight, 1);
      }
      if (width === 1440) {
        fs.mkdirSync("docs/screenshots", { recursive: true });
        await page.screenshot({ path: `docs/screenshots/${slug}.png` });
      }
    });
  }
test("Parking search, create, edit and persistence", async ({ page }) => {
  await page.goto("/parking");
  await page
    .getByRole("button", { name: "+ Thêm bãi đỗ", exact: true })
    .click();
  const d = page.getByRole("dialog");
  await d.getByLabel("Tên bãi đỗ", { exact: true }).fill("Bãi xe Kiểm thử");
  await d.getByLabel("Địa điểm", { exact: true }).fill("Hải Châu, Đà Nẵng");
  await d.getByLabel("Sức chứa", { exact: true }).fill("60");
  await d.getByRole("button", { name: "Lưu bãi đỗ demo" }).click();
  await page
    .getByRole("textbox", { name: "Tìm tên bãi đỗ hoặc địa điểm" })
    .fill("Kiểm thử");
  await expect(
    page.getByRole("button", { name: "Bãi xe Kiểm thử", exact: true }),
  ).toBeVisible();
  await page
    .getByRole("button", { name: "Sửa Bãi xe Kiểm thử", exact: true })
    .click();
  await page
    .getByRole("dialog")
    .getByLabel("Xe đang trong bãi", { exact: true })
    .fill("20");
  await page.getByRole("button", { name: "Lưu bãi đỗ demo" }).click();
  await expect(page.locator("tbody")).toContainText("20 / 60");
  await page.reload();
  await page
    .getByRole("textbox", { name: "Tìm tên bãi đỗ hoặc địa điểm" })
    .fill("Kiểm thử");
  await expect(page.locator("tbody")).toContainText("20 / 60");
  await page
    .getByRole("textbox", { name: "Tìm tên bãi đỗ hoặc địa điểm" })
    .fill("no such parking");
  await expect(page.getByText("Không tìm thấy kết quả phù hợp.")).toBeVisible();
});
test("Bookings filter, cancel simulation and CSV download", async ({
  page,
}) => {
  await page.goto("/bookings");
  await page
    .getByRole("combobox", { name: "Trạng thái đặt chỗ" })
    .selectOption("Hoàn thành");
  await page.getByRole("button", { name: "Lọc dữ liệu", exact: true }).click();
  const states = await page.locator("tbody .badge").allTextContents();
  expect(states.length).toBeGreaterThan(0);
  expect(states.every((s) => s === "Hoàn thành")).toBe(true);
  const download = page.waitForEvent("download");
  await page.getByRole("button", { name: "Xuất danh sách" }).click();
  expect((await download).suggestedFilename()).toBe(
    "smartpark-dat-cho-demo.csv",
  );
  await page.goto("/bookings?q=SP-1022-007");
  await page.getByRole("button", { name: "SP-1022-007", exact: true }).click();
  await expect(page.getByRole("dialog")).toContainText("Không xác thực QR");
  await page
    .getByRole("button", { name: "Hủy đặt chỗ demo", exact: true })
    .click();
  await expect(page.locator("tbody .badge")).toHaveText("Đã hủy");
});
test("Staff can be added and assigned locally", async ({ page }) => {
  await page.goto("/staff");
  await page
    .getByRole("button", { name: "+ Thêm nhân viên", exact: true })
    .click();
  const d = page.getByRole("dialog");
  await d.getByLabel("Họ tên", { exact: true }).fill("Nguyễn Test");
  await d
    .getByLabel("Email nhân viên", { exact: true })
    .fill("test@smartpark.vn");
  await d.getByLabel("Bãi đỗ được phân công").selectOption("lot-2");
  await d.getByLabel("Ca làm việc", { exact: true }).selectOption("night");
  await d.getByRole("button", { name: "Lưu nhân viên demo" }).click();
  await page
    .getByRole("textbox", { name: "Tìm tên nhân viên", exact: true })
    .fill("Nguyễn Test");
  await expect(page.locator("tbody")).toContainText("23:00–07:00");
  await page.getByRole("button", { name: "Nguyễn Test", exact: true }).click();
  await expect(
    page.getByRole("dialog").getByLabel("Bãi đỗ được phân công"),
  ).toHaveValue("lot-2");
});
test("Pricing and rule changes persist independently per parking lot", async ({
  page,
}) => {
  await page.goto("/settings");
  await page
    .getByRole("textbox", { name: "Phí ô tô / giờ", exact: true })
    .fill("20000");
  await expect(
    page.getByText("Ước tính: ô tô đỗ 2 giờ = 40.000đ", { exact: true }),
  ).toBeVisible();
  await page
    .getByRole("switch", { name: "Cho phép đặt trước", exact: true })
    .click();
  await page.getByRole("button", { name: "Lưu thay đổi", exact: true }).click();
  await expect(page.getByRole("status")).toContainText("Chưa áp dụng");
  await page.reload();
  await expect(
    page.getByRole("textbox", { name: "Phí ô tô / giờ", exact: true }),
  ).toHaveValue("20.000");
  await expect(
    page.getByRole("switch", { name: "Cho phép đặt trước", exact: true }),
  ).toHaveAttribute("aria-checked", "false");
  await page
    .getByRole("combobox", { name: "Bãi đỗ áp dụng giá vé" })
    .selectOption("lot-2");
  await expect(
    page.getByRole("textbox", { name: "Phí ô tô / giờ", exact: true }),
  ).toHaveValue("15.000");
});
test("Global search navigates to matching record and mobile navigation works", async ({
  page,
}) => {
  await page.goto("/");
  await page
    .getByRole("textbox", { name: "Tìm kiếm toàn hệ thống" })
    .fill("SP-1022-007");
  await page.locator(".global-results").getByRole("button").first().click();
  await expect(page.locator("tbody")).toContainText("SP-1022-007");
  await expect(page.locator("tbody tr")).toHaveCount(1);
  await page.setViewportSize({ width: 390, height: 844 });
  await page
    .getByRole("button", { name: "Mở menu quản trị", exact: true })
    .click();
  await page
    .getByRole("navigation")
    .getByRole("link", { name: "Báo cáo doanh thu", exact: true })
    .click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Báo cáo & doanh thu",
  );
});
test("Report exports an explicitly named demo CSV", async ({ page }) => {
  await page.goto("/reports");
  const download = page.waitForEvent("download");
  await page.getByRole("button", { name: "Xuất báo cáo", exact: true }).click();
  expect((await download).suggestedFilename()).toContain("demo");
  await expect(page.getByRole("status")).toContainText(
    "không phải báo cáo giao dịch thực tế",
  );
});
