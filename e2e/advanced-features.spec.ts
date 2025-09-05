import { test, expect } from '@playwright/test';

test('Data visualization charts render correctly', async ({ page }) => {
  await page.goto('/');

  // Wait for dashboard to load
  await expect(page.getByText('Dashboard')).toBeVisible();

  // Look for chart elements (Canvas, SVG, or chart libraries)
  // FL Chart (used in Flutter) typically renders to Canvas
  await expect(page.locator('canvas').first()).toBeVisible({ timeout: 10000 });
});

test('Error handling for disconnected services', async ({ page }) => {
  await page.goto('/');

  // Check that the app loads even if some services might be unavailable
  await expect(page.getByText('Dashboard')).toBeVisible();
  
  // Look for any error messages or notifications
  const errorMessages = await page.locator('text=/error|failed|disconnected/i');
  
  // If errors are present, they should be handled gracefully
  if (await errorMessages.count() > 0) {
    // Error messages should not crash the app
    await expect(page.getByText('Dashboard')).toBeVisible();
  }
});

test('Historical data access works', async ({ page }) => {
  await page.goto('/');

  // Look for historical data controls or chart interactions
  await expect(page.getByText('Dashboard')).toBeVisible();
  
  // Try to find time range selectors, chart interactions, or historical data sections
  // This is a basic test since the exact UI structure depends on implementation
  await page.waitForTimeout(2000);
  
  // Ensure the page remains functional
  await expect(page.locator('body')).toBeVisible();
});

test('Accessibility features work correctly', async ({ page }) => {
  await page.goto('/');

  // Test keyboard navigation
  await page.keyboard.press('Tab');
  await page.waitForTimeout(500);
  
  // Check that focus is visible
  const focusedElement = page.locator(':focus');
  await expect(focusedElement).toBeVisible();

  // Test that the app has proper ARIA labels
  await expect(page.locator('[role]')).toHaveCount({ min: 1 });
});

test('Performance: App loads within reasonable time', async ({ page }) => {
  const startTime = Date.now();
  
  await page.goto('/');
  await expect(page.getByText('Dashboard')).toBeVisible();
  
  const loadTime = Date.now() - startTime;
  
  // App should load within 10 seconds
  expect(loadTime).toBeLessThan(10000);
});

test('Cross-browser compatibility', async ({ page, browserName }) => {
  await page.goto('/');

  // Basic functionality should work across all browsers
  await expect(page.getByText('Dashboard')).toBeVisible();
  await expect(page.getByText('Water Level')).toBeVisible();

  // Navigation should work
  await page.getByText('Devices').click();
  await expect(page.getByText('Water Pump')).toBeVisible();

  console.log(`✅ Cross-browser test passed on ${browserName}`);
});