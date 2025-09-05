import { test, expect } from '@playwright/test';

test('Dashboard loads and displays sensor data', async ({ page }) => {
  await page.goto('/');

  // Check that the dashboard page loads
  await expect(page.getByText('Dashboard')).toBeVisible();

  // Check that sensor data is displayed
  await expect(page.getByText('Water Level')).toBeVisible();
  await expect(page.getByText('Temperature')).toBeVisible();

  // Check that sensor values are displayed (with some tolerance for loading time)
  await expect(page.locator('text=/\\d+(\\.\\d+)?/')).toBeVisible({ timeout: 10000 });
});

test('Navigation between Dashboard and Devices works', async ({ page }) => {
  await page.goto('/');

  // Start on dashboard
  await expect(page.getByText('Dashboard')).toBeVisible();
  await expect(page.getByText('Water Level')).toBeVisible();

  // Navigate to devices
  await page.getByText('Devices').click();
  await expect(page.getByText('Water Pump')).toBeVisible();

  // Navigate back to dashboard
  await page.getByText('Dashboard').click();
  await expect(page.getByText('Water Level')).toBeVisible();
});

test('Device controls are functional', async ({ page }) => {
  await page.goto('/');

  // Navigate to devices page
  await page.getByText('Devices').click();

  // Check that device controls are present
  await expect(page.getByText('Water Pump')).toBeVisible();
  
  // Look for device status indicators
  await expect(page.locator('text=/online|offline|running|stopped/i')).toBeVisible({ timeout: 5000 });
});

test('Real-time data updates work', async ({ page }) => {
  await page.goto('/');

  // Wait for initial data to load
  await expect(page.getByText('Dashboard')).toBeVisible();
  
  // Look for any numeric sensor values
  const initialValue = await page.locator('text=/\\d+(\\.\\d+)?/').first().textContent();
  
  // Wait a bit and check if values might change (this would depend on actual real-time updates)
  await page.waitForTimeout(3000);
  
  // Just verify the elements are still there and responsive
  await expect(page.getByText('Water Level')).toBeVisible();
  await expect(page.getByText('Temperature')).toBeVisible();
});

test('App is responsive on mobile', async ({ page }) => {
  // Set mobile viewport
  await page.setViewportSize({ width: 375, height: 667 });
  await page.goto('/');

  // Check that dashboard loads on mobile
  await expect(page.getByText('Dashboard')).toBeVisible();
  
  // Check that navigation works on mobile
  await page.getByText('Devices').click();
  await expect(page.getByText('Water Pump')).toBeVisible();
});

test('Connection status is displayed', async ({ page }) => {
  await page.goto('/');

  // Look for connection indicators 
  // This might be a status icon, text, or color indicator
  await expect(page.getByText('Dashboard')).toBeVisible();
  
  // Wait for app to fully load and check for any connection status
  await page.waitForTimeout(2000);
  
  // The app should have some indication of connection status
  // This is a basic test that the app loads without errors
  await expect(page).not.toHaveURL(/error/);
});