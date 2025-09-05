# End-to-End Testing with Playwright

This directory contains Playwright end-to-end tests for the Hydroponic Monitor application.

## Setup

1. Install Playwright dependencies:
   ```bash
   npm install
   ```

2. Install Playwright browsers:
   ```bash
   npx playwright install
   ```

## Running Tests

### All tests
```bash
npm test
```

### Tests with browser UI visible
```bash
npm run test:headed
```

### Debug mode (step through tests)
```bash
npm run test:debug
```

### View test results
```bash
npm run test:report
```

## Test Structure

### `hydroponic-monitor.spec.ts`
- Basic application functionality tests
- Navigation between pages
- Device controls
- Real-time data updates
- Mobile responsiveness
- Connection status

### `advanced-features.spec.ts`
- Data visualization charts
- Error handling
- Historical data access
- Accessibility features
- Performance testing
- Cross-browser compatibility

## Test Strategy

These E2E tests complement the Dart unit and integration tests by:

1. **Testing the complete user journey** - From loading the app to interacting with devices
2. **Cross-browser compatibility** - Ensuring the Flutter web app works across Chrome, Firefox, Safari
3. **Mobile responsiveness** - Testing on various screen sizes
4. **Real user interactions** - Clicking, typing, navigation as a real user would
5. **Performance validation** - Ensuring the app loads within reasonable time
6. **Accessibility compliance** - Testing keyboard navigation and ARIA labels

## CI/CD Integration

The tests are configured to run against the Flutter web server on `http://localhost:8080`.
The Playwright config automatically starts the Flutter server before running tests.

For CI environments, ensure the web server is available or modify the configuration
to point to your deployed application URL.

## Browser Support

Tests run against:
- Desktop Chrome
- Desktop Firefox
- Desktop Safari (WebKit)
- Mobile Chrome (Pixel 5 viewport)
- Mobile Safari (iPhone 12 viewport)

## Debugging Tips

1. Use `--headed` to see the browser during test execution
2. Use `--debug` to step through tests interactively
3. Screenshots are automatically captured on test failures
4. Use `page.pause()` in tests for manual debugging
5. Check the HTML report for detailed test results and traces