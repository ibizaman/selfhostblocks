// Use Playwright Test's built-in golden comparisons, baseline updates, and diffs:
// https://playwright.dev/docs/test-snapshots
// Python can take screenshots, but its Playwright assertions have no equivalent
// to toHaveScreenshot(); matching goldens would need a separate comparison tool.
// https://playwright.dev/python/docs/screenshots#capture-into-buffer
// https://playwright.dev/python/docs/test-assertions#auto-retrying-assertions
const { test, expect } = require('@playwright/test');

test('Nextcloud manual layout', async ({ page }) => {
  const response = await page.goto('/services-nextcloud.html');
  expect(response.status()).toBe(200);
  await expect(page.getByRole('main')).toBeVisible();
  await expect(page).toHaveScreenshot('nextcloud.png');
});
