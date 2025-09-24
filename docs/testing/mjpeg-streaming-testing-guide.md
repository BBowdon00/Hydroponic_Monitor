# MJPEG Streaming Server Framework Testing Guide

## Overview

This document provides comprehensive testing procedures for the MJPEG streaming server framework in the Hydroponic Monitor application. It covers automated test execution, manual testing procedures, and performance validation.

## Testing Architecture

The MJPEG streaming framework testing consists of three layers:

1. **Unit Tests** - Test individual components and business logic
2. **Integration Tests** - Test component interactions and data flow 
3. **Widget Tests** - Test UI components and user interactions
4. **Manual Tests** - Test real-world scenarios and edge cases

## Prerequisites

### Development Environment
- Flutter 3.35+ with Dart 3.9+
- Git for version control
- A mock MJPEG server for testing (optional)

### Test MJPEG Server Setup (Optional)

For comprehensive testing, set up a local MJPEG server:

```bash
# Using Python HTTP server with MJPEG simulation
python3 -m http.server 8080

# Or using Node.js/Express MJPEG server
npm install express
# Create server.js with MJPEG streaming endpoint
```

## Automated Test Execution

### 1. Unit Tests

Test core VideoState and VideoStateNotifier logic:

```bash
# Run video state unit tests
flutter test test/unit/video_state_test.dart --reporter=compact

# Expected output: 22 tests passing
# Tests cover: state management, transitions, URL handling, latency simulation
```

**Key Test Areas:**
- VideoState model creation and copying
- VideoStateNotifier initialization and default state
- URL updating and validation
- Connection state transitions (disconnected → connecting → connected)
- Disconnect functionality
- Latency refresh simulation
- Provider integration and isolation

### 2. Integration Tests

Test MJPEG streaming system integration:

```bash
# Run video streaming integration tests
flutter test test/integration/video_streaming_test.dart --reporter=compact

# Expected output: 13 tests passing
# Tests cover: URL validation, connection simulation, state management
```

**Key Test Areas:**
- Environment configuration handling
- URL format validation
- Connection behavior simulation
- State transition tracking
- Resource management
- Network condition simulation

### 3. Widget Tests

Test VideoPage UI components:

```bash
# Run video page widget tests
flutter test test/presentation/pages/video_page_test.dart --reporter=compact

# Note: Some tests may have issues with widget finding - see Known Issues
```

**Key Test Areas:**
- UI component rendering
- Connection status display
- URL input functionality
- Button state management
- Layout adaptation to connection state

### 4. Run All MJPEG Tests

```bash
# Run all MJPEG-related tests
flutter test test/unit/video_state_test.dart test/integration/video_streaming_test.dart --reporter=compact
```

## Manual Testing Procedures

### Basic Functionality Testing

#### 1. Initial State Verification
1. Launch the application
2. Navigate to the Video page
3. **Verify:**
   - Status badge shows "Disconnected" (red/offline)
   - URL field contains default URL: `http://192.168.1.100:8080/stream`
   - Connect button is enabled and shows "Connect"
   - Video area shows placeholder with "No Video Stream" message
   - No refresh button visible

#### 2. URL Input Testing
1. Clear the URL field
2. Enter test URLs:
   ```
   http://raspberry.local:8080/stream
   https://camera.local:8443/mjpeg
   http://192.168.1.200:8080/video.mjpeg
   ```
3. **Verify:**
   - URLs are accepted and displayed
   - Field accepts various URL formats
   - No validation errors for valid HTTP/HTTPS URLs

#### 3. Connection Process Testing
1. Click "Connect" button
2. **Verify:**
   - Button changes to "Connecting..." and becomes disabled
   - Status badge shows "Disconnected" initially
3. Wait 2-3 seconds for simulated connection
4. **Verify:**
   - Button changes to "Disconnect" with disconnect icon
   - Status badge shows "Connected" (green/online)
   - Video area shows "Live Video Stream" message
   - Stream URL is displayed in video area
   - Refresh button appears
   - Video controls card appears with:
     - Resolution: 1280×720
     - FPS: 30
     - Latency: 120-220ms (variable)

#### 4. Connected State Testing
1. While connected, click "Refresh" button
2. **Verify:**
   - Latency value changes (simulates refresh)
   - Other values remain stable
   - Connection remains active

#### 5. Disconnection Testing
1. Click "Disconnect" button
2. **Verify:**
   - Immediate return to disconnected state
   - Status badge shows "Disconnected"
   - Video area shows placeholder
   - Refresh button disappears
   - Video controls card disappears
   - URL is preserved

### Edge Case Testing

#### 1. Rapid Button Presses
1. Rapidly click "Connect" button multiple times
2. **Verify:**
   - Only one connection attempt initiated
   - Button becomes disabled during connection
   - No duplicate state changes

#### 2. URL Changes During Connection
1. Start connection process
2. While connecting, change URL
3. **Verify:**
   - URL change is accepted
   - Connection completes with new URL
4. Disconnect and verify URL is preserved

#### 3. Empty/Invalid URLs
1. Clear URL field completely
2. Attempt to connect
3. **Verify:**
   - Connection attempt proceeds (simulated)
   - No crashes or errors
4. Test with invalid URLs:
   ```
   not-a-url
   ftp://invalid.com/stream
   javascript:alert('test')
   ```

#### 4. Connection State Transitions
1. Test complete flow: Disconnected → Connecting → Connected → Disconnected
2. **Verify:**
   - Each state is visually distinct
   - Transitions are smooth
   - No intermediate glitches

### Performance Testing

#### 1. Latency Simulation
1. Connect to stream
2. Click "Refresh" button 10 times rapidly
3. **Verify:**
   - Latency values vary between 100-250ms
   - Values are realistic for network latency
   - UI remains responsive

#### 2. Memory Usage
1. Connect and disconnect multiple times (10+ cycles)
2. **Verify:**
   - No memory leaks observed
   - App remains responsive
   - No degradation in performance

#### 3. State Management
1. Open multiple tabs/instances (if supported)
2. Test independent state management
3. **Verify:**
   - Each instance maintains separate state
   - No cross-contamination

### Accessibility Testing

#### 1. Keyboard Navigation
1. Use Tab key to navigate through controls
2. **Verify:**
   - All interactive elements are focusable
   - Focus indicators are visible
   - Enter key activates buttons

#### 2. Screen Reader Compatibility
1. Test with screen reader (if available)
2. **Verify:**
   - Status changes are announced
   - Button states are clear
   - Form fields have proper labels

### Cross-Platform Testing

Test on available platforms:
- **Web**: Browser compatibility (Chrome, Firefox, Safari, Edge)
- **Desktop**: Windows, macOS, Linux (if supported)
- **Mobile**: Android, iOS (if supported)

## Real Network Testing (Advanced)

### Local MJPEG Server Setup

For realistic testing, set up a local MJPEG server:

#### Option 1: Python Simple Server
```bash
# Create a simple MJPEG endpoint simulation
cd /tmp
mkdir mjpeg-test
cd mjpeg-test

# Create simple response
echo "HTTP/1.1 200 OK
Content-Type: multipart/x-mixed-replace; boundary=frame

--frame
Content-Type: image/jpeg

[Binary JPEG data would go here]
--frame" > stream_response.txt

python3 -m http.server 8080
```

#### Option 2: FFmpeg MJPEG Stream
```bash
# Generate test video stream (requires FFmpeg)
ffmpeg -f lavfi -i testsrc=duration=60:size=640x480:rate=30 \
       -f mjpeg -q:v 2 \
       -c:v mjpeg \
       -boundary_tag frame \
       http://localhost:8080/stream
```

### Network Condition Testing

1. **Normal Connection**: Test with local server
2. **Slow Connection**: Simulate network delays
3. **Interrupted Connection**: Stop/start server during connection
4. **Invalid Server**: Test with non-MJPEG endpoints

## Test Results Documentation

### Expected Test Coverage

| Test Type | Count | Status | Notes |
|-----------|--------|--------|-------|
| Unit Tests | 22 | ✅ Pass | Core VideoState logic |
| Integration Tests | 13 | ✅ Pass | System integration |
| Widget Tests | 12 | ⚠️ Partial | Some widget finding issues |
| Manual Tests | 15 | ✅ Pass | UI and UX validation |

### Known Issues

1. **Widget Tests**: Some button finding issues in complex widget trees
2. **Real Streaming**: Current implementation uses simulation only
3. **Error Handling**: Limited network error handling in current version

### Performance Benchmarks

- **Connection Time**: 2 seconds (simulated)
- **UI Response Time**: < 100ms for state changes
- **Memory Usage**: Stable across connection cycles
- **Latency Simulation**: 100-250ms range

## Troubleshooting

### Common Issues

#### Test Failures
- **Environment Issues**: Ensure Flutter/Dart versions match requirements
- **Widget Test Failures**: May be due to widget tree changes
- **Integration Test Failures**: Check provider container setup

#### Manual Testing Issues
- **Connection Not Working**: Verify it's simulation-based
- **UI Not Updating**: Check provider integration
- **State Inconsistencies**: Restart app and retry

#### Performance Issues
- **Slow UI**: Check for widget rebuilds
- **Memory Leaks**: Monitor container disposal
- **State Corruption**: Verify provider isolation

### Debug Commands

```bash
# Run tests with verbose output
flutter test --reporter=expanded

# Run specific test file with debug info
flutter test test/unit/video_state_test.dart --debug

# Check Flutter doctor for environment issues
flutter doctor -v

# Analyze code for issues
flutter analyze
```

## Future Enhancements

### Planned Testing Improvements

1. **Real Network Integration**: Replace simulation with actual HTTP/MJPEG clients
2. **Error Scenario Testing**: Add network timeout and error handling tests
3. **Performance Benchmarking**: Add automated performance regression tests
4. **Cross-Platform Validation**: Expand platform-specific testing
5. **Accessibility Testing**: Add automated accessibility validation

### Test Infrastructure

1. **Mock Server Integration**: Add dedicated MJPEG mock server
2. **Automated Visual Testing**: Screenshot comparison tests
3. **Load Testing**: Test with multiple concurrent streams
4. **Security Testing**: Validate URL handling and input sanitization

---

## Conclusion

This testing guide provides comprehensive coverage of the MJPEG streaming framework. The combination of automated and manual testing ensures reliability, performance, and usability of the video streaming features.

For questions or issues with testing procedures, refer to the project documentation or contact the development team.

---

*Last Updated: 2025-09-24*
*Version: 1.0*