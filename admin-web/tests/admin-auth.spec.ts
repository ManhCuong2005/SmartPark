import { test, expect } from "@playwright/test";
import type { Page } from "@playwright/test";

async function isolateAuth(page: Page, { delay = 0, failReset = false } = {}) {
  const requests: { path: string; body: Record<string, unknown> }[] = [];
  await page.route(
    "https://odpxmbkzdqutxitsdfaw.supabase.co/**",
    async (route) => {
      const path = new URL(route.request().url()).pathname;
      requests.push({ path, body: route.request().postDataJSON() ?? {} });
      if (delay) await new Promise((resolve) => setTimeout(resolve, delay));
      if (path === "/auth/v1/recover" && !failReset)
        return route.fulfill({ json: {} });
      return route.fulfill({
        status: path.endsWith("recover") ? 429 : 400,
        json: {
          code: path.endsWith("recover")
            ? "over_email_send_rate_limit"
            : "invalid_credentials",
          msg: path.endsWith("recover")
            ? "Email rate limit exceeded"
            : "Invalid login credentials",
        },
      });
    },
  );
  return requests;
}

for (const width of [320, 390, 768, 1024, 1440]) {
  test(`login fits ${width}px and keeps inputs usable`, async ({ page }) => {
    await isolateAuth(page);
    await page.setViewportSize({ width, height: 900 });
    await page.goto("/");
    await expect(
      page.getByRole("heading", { name: "Đăng nhập chủ bãi", exact: true }),
    ).toBeVisible();
    await page.getByLabel("Email", { exact: true }).fill("owner@test.invalid");
    await page.getByLabel("Mật khẩu", { exact: true }).fill("test-password");
    await expect(
      page.getByRole("button", { name: "Đăng nhập", exact: true }),
    ).toBeEnabled();
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= window.innerWidth,
      ),
    ).toBeTruthy();
    await page.evaluate(() => document.fonts.ready);
    if ([390, 1440].includes(width))
      await page.screenshot({
        path: `test-results/login-${width}.png`,
        fullPage: true,
        animations: "disabled",
      });
  });
}
test("password visibility toggles without clearing either field", async ({
  page,
}) => {
  await isolateAuth(page);
  await page.goto("/");
  const field = page.getByLabel("Mật khẩu", { exact: true });
  await field.fill("private-test-password");
  await expect(field).toHaveAttribute("type", "password");
  await page.getByRole("button", { name: "Hiện mật khẩu" }).click();
  await expect(field).toHaveAttribute("type", "text");
  await expect(field).toHaveValue("private-test-password");
  await page.getByRole("button", { name: "Ẩn mật khẩu" }).click();
  await expect(field).toHaveAttribute("type", "password");
});
test("failed sign-in shows a clear error and busy state prevents duplicate requests", async ({
  page,
}) => {
  const requests = await isolateAuth(page, { delay: 350 });
  await page.goto("/");
  await page.getByLabel("Email", { exact: true }).fill("owner@test.invalid");
  await page.getByLabel("Mật khẩu", { exact: true }).fill("wrong-password");
  await page.getByRole("button", { name: "Đăng nhập", exact: true }).click();
  await expect(
    page.getByRole("button", { name: "Đang đăng nhập…" }),
  ).toBeDisabled();
  await expect(page.getByRole("alert")).toContainText(
    "Email hoặc mật khẩu chưa chính xác",
  );
  expect(requests.filter((r) => r.path === "/auth/v1/token")).toHaveLength(1);
  await page.getByLabel("Mật khẩu", { exact: true }).fill("another-password");
  await expect(page.getByRole("alert")).toHaveCount(0);
});
test("password reset uses the entered email and shows delivery-neutral confirmation", async ({
  page,
}) => {
  const requests = await isolateAuth(page);
  await page.goto("/");
  await page.getByLabel("Email", { exact: true }).fill("owner@test.invalid");
  await page.getByRole("button", { name: "Quên mật khẩu?" }).click();
  await expect(page.getByLabel("Email", { exact: true })).toHaveValue(
    "owner@test.invalid",
  );
  await page.getByRole("button", { name: "Gửi liên kết khôi phục" }).click();
  await expect(page.getByRole("status")).toContainText("Nếu email hợp lệ");
  expect(requests.find((r) => r.path === "/auth/v1/recover")?.body.email).toBe(
    "owner@test.invalid",
  );
  await page.getByRole("button", { name: "Quay lại đăng nhập" }).click();
  await expect(
    page.getByRole("heading", { name: "Đăng nhập chủ bãi" }),
  ).toBeVisible();
});
test("dark theme persists and respects reduced motion", async ({ page }) => {
  await isolateAuth(page);
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  await page.getByRole("button", { name: "Chuyển sang giao diện tối" }).click();
  await expect(page.locator("html")).toHaveClass(/dark/);
  await page.reload();
  await expect(
    page.getByRole("button", { name: "Chuyển sang giao diện sáng" }),
  ).toHaveAttribute("aria-pressed", "true");
  expect(
    await page
      .locator(".auth-form-content")
      .evaluate((el) => getComputedStyle(el).animationName),
  ).toBe("none");
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({
    path: "test-results/login-dark.png",
    fullPage: true,
  });
});
