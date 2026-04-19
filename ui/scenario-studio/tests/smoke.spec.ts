import { test, expect } from "@playwright/test";

test("basic auth + scenarios page loads", async ({ page }) => {
  await page.goto("/runs");
  await expect(page.getByRole("heading", { name: "Runs" })).toBeVisible();
});

test("run replay UI loads against an existing completed run", async ({ page }) => {
  const runId = "D57E275A-3341-41A2-9654-7FC61D5EE946";

  await page.goto(`/runs/${encodeURIComponent(runId)}`);

  await expect(page.getByRole("heading", { name: "Run" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Replay Wizard" }).first()).toBeVisible();
  const nextConfigure = page.getByRole("button", { name: /Next: Configure Transformations/i }).first();
  await expect(nextConfigure).toBeVisible();
  await nextConfigure.click();
  await expect(page.getByRole("heading", { name: "Configure" })).toBeVisible();
  await expect(page.getByText(/Load the domain contract to configure field generators and transformations\./i)).toBeVisible();
});
