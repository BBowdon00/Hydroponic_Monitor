#!/bin/bash

# Playwright Web Integration Test for Hydroponic Monitor
# This script builds and tests the Flutter web app using Playwright browser automation

set -e

echo "🚀 Starting Playwright Integration Test for Hydroponic Monitor Web App"

# Configuration
FLUTTER_PROJECT_DIR="/home/runner/work/Hydroponic_Monitor/Hydroponic_Monitor"
TEST_PORT=8083
BUILD_DIR="$FLUTTER_PROJECT_DIR/build/web"
LOG_FILE="/tmp/playwright_test.log"

# Function to cleanup processes
cleanup() {
    echo "🧹 Cleaning up..."
    pkill -f "python3 -m http.server $TEST_PORT" || true
    pkill -f "docker compose" || true
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Step 1: Build Flutter Web App (without CDN to avoid external dependencies)
echo "📦 Building Flutter web app without CDN dependencies..."
cd "$FLUTTER_PROJECT_DIR"
flutter build web --no-web-resources-cdn --release > "$LOG_FILE" 2>&1
echo "✅ Flutter web build completed"

# Step 2: Start web server
echo "🌐 Starting web server on port $TEST_PORT..."
cd "$BUILD_DIR"
python3 -m http.server $TEST_PORT --bind 0.0.0.0 > /dev/null 2>&1 &
WEB_SERVER_PID=$!

# Wait for server to start
sleep 3

# Step 3: Start MQTT and InfluxDB services for testing
echo "🐳 Starting Docker services for integration testing..."
cd "$FLUTTER_PROJECT_DIR/test/integration"
docker compose up -d > /dev/null 2>&1 || echo "⚠️ Warning: Could not start Docker services"

# Wait for services to be ready
sleep 5

# Step 4: Run Playwright tests via Python script
echo "🎭 Running Playwright tests..."

cat > /tmp/playwright_test.py << 'EOF'
#!/usr/bin/env python3
import asyncio
import json
import time
import sys
from playwright.async_api import async_playwright

async def test_dashboard():
    """Test the Flutter web dashboard using Playwright."""
    print("🎭 Starting Playwright browser tests...")
    
    async with async_playwright() as p:
        # Launch browser
        browser = await p.chromium.launch(headless=True, args=['--no-sandbox'])
        page = await browser.new_page()
        
        # Set console message handler
        page.on("console", lambda msg: print(f"CONSOLE [{msg.type}]: {msg.text}"))
        
        try:
            print("🌐 Navigating to Flutter app...")
            await page.goto("http://localhost:8083", wait_until="networkidle", timeout=30000)
            
            # Wait for Flutter app to initialize
            print("⏳ Waiting for app initialization...")
            await page.wait_for_timeout(10000)
            
            # Take initial screenshot
            await page.screenshot(path="/tmp/dashboard_initial.png", full_page=True)
            print("📸 Initial screenshot saved")
            
            # Check if app loaded successfully
            title = await page.title()
            print(f"📄 Page title: {title}")
            
            # Check for app content
            url = page.url
            print(f"🔗 Current URL: {url}")
            
            # Look for specific elements
            elements_to_check = [
                "button[role='button']:has-text('Dashboard')",
                "button[role='button']:has-text('Devices')",
                "button[role='button']:has-text('Video')",
                "button[role='button']:has-text('Charts')",
                "button[role='button']:has-text('Settings')",
            ]
            
            found_elements = 0
            for selector in elements_to_check:
                try:
                    await page.wait_for_selector(selector, timeout=2000)
                    found_elements += 1
                    print(f"✅ Found element: {selector}")
                except:
                    print(f"❌ Could not find element: {selector}")
            
            # Check for initialization errors
            error_indicators = [
                "text=Failed to initialize",
                "text=Instance of 'NotInitializedError'",
                "text=Error",
            ]
            
            has_errors = False
            for error_selector in error_indicators:
                try:
                    await page.wait_for_selector(error_selector, timeout=1000)
                    print(f"❌ Found error indicator: {error_selector}")
                    has_errors = True
                except:
                    pass
            
            # Check for loading or content
            loading_indicators = [
                "text=Initializing data services",
                "text=Loading",
                "text=Sensor Status",
                "text=Device Control",
            ]
            
            has_content = False
            for content_selector in loading_indicators:
                try:
                    await page.wait_for_selector(content_selector, timeout=2000)
                    print(f"✅ Found content: {content_selector}")
                    has_content = True
                    break
                except:
                    pass
            
            # Final screenshot
            await page.screenshot(path="/tmp/dashboard_final.png", full_page=True)
            print("📸 Final screenshot saved")
            
            # Test results
            print("\n📊 TEST RESULTS:")
            print(f"   Title correct: {'✅' if 'Hydroponic' in title else '❌'}")
            print(f"   Navigation elements: {found_elements}/5")
            print(f"   Has initialization errors: {'❌' if has_errors else '✅'}")
            print(f"   Has content/loading: {'✅' if has_content else '❌'}")
            print(f"   Dashboard route: {'✅' if '#/dashboard' in url else '❌'}")
            
            # Overall success
            success = (
                'Hydroponic' in title and 
                found_elements >= 3 and 
                not has_errors and 
                (has_content or found_elements >= 4)
            )
            
            print(f"\n🎯 OVERALL TEST RESULT: {'✅ PASSED' if success else '❌ FAILED'}")
            
            return success
            
        except Exception as e:
            print(f"💥 Test failed with exception: {e}")
            await page.screenshot(path="/tmp/dashboard_error.png", full_page=True)
            return False
        finally:
            await browser.close()

if __name__ == "__main__":
    success = asyncio.run(test_dashboard())
    sys.exit(0 if success else 1)
EOF

# Make the script executable and run it
chmod +x /tmp/playwright_test.py
python3 -m pip install playwright > /dev/null 2>&1 || echo "⚠️ Playwright not installed, trying to install..."
python3 -m playwright install chromium > /dev/null 2>&1 || echo "⚠️ Could not install Playwright browser"

# Run the test
if python3 /tmp/playwright_test.py; then
    echo "🎉 Playwright integration tests PASSED!"
    exit 0
else
    echo "💥 Playwright integration tests FAILED!"
    echo "📋 Check logs at: $LOG_FILE"
    exit 1
fi