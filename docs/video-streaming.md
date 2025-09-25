# Video Streaming Platform Documentation

This document describes the MJPEG video streaming implementation for the Hydroponic Monitor application, including platform differences, setup instructions, and limitations.

## Overview

The application supports MJPEG (Motion JPEG) video streaming with platform-conditional implementations:

- **Native platforms** (Android, iOS, Windows, macOS, Linux): Full-featured implementation using `dart:io` HttpClient
- **Web platform**: Browser-compatible implementation using HTML Image elements and Canvas API

## Platform Implementations

### Native Platforms (IO)

**File**: `lib/core/video/mjpeg_stream_controller_io.dart`

**Features**:
- Direct HTTP multipart/x-mixed-replace stream parsing
- Full boundary detection and frame extraction
- Real-time FPS calculation
- Configurable timeouts and frame size limits
- Direct byte array access to frame data

**Implementation**:
- Uses `dart:io` HttpClient for HTTP requests
- Custom multipart boundary parsing
- Stream subscription for continuous data flow
- Proper error handling and cleanup

### Web Platform

**File**: `lib/core/video/mjpeg_stream_controller_web.dart`

**Features**:
- Browser-native multipart stream handling
- Canvas-based frame capture
- CORS-aware error handling
- Graceful degradation for FPS measurement

**Implementation**:
- Uses `package:web` HTML Image elements
- Browser handles multipart/x-mixed-replace natively
- Canvas API for frame data extraction
- Cross-origin resource sharing (CORS) support

**Limitations**:
- Limited FPS measurement accuracy
- Simplified frame data representation
- Dependent on browser CORS policies
- May have performance constraints compared to native

## Connection Phases

The streaming system uses explicit connection phases for clear state management:

```dart
enum VideoConnectionPhase {
  idle,                 // No connection attempted
  connecting,           // Attempting to establish connection
  waitingFirstFrame,    // Connected but waiting for first frame
  playing,              // Successfully streaming video
  error                 // Error occurred during connection/streaming
}
```

### Phase Transitions

1. **idle → connecting**: User initiates connection
2. **connecting → waitingFirstFrame**: Stream connection established
3. **waitingFirstFrame → playing**: First frame received
4. **any → error**: Error occurs during connection or streaming
5. **any → idle**: User disconnects or stream ends cleanly

## Feature Flag Configuration

### Enabling Real MJPEG Streaming

Set the `REAL_MJPEG` environment variable to enable actual MJPEG streaming:

```bash
export REAL_MJPEG=true
```

Or add to your `.env` file:
```
REAL_MJPEG=true
MJPEG_URL=http://your-camera-server:8080/stream
```

### Simulation Mode

When `REAL_MJPEG=false` (default), the application runs in simulation mode:

- Clear "Simulation Mode" badge in UI
- No actual network requests made  
- Phase transitions simulated with delays
- Honest messaging about simulation state

## Setup Instructions

### Environment Variables

Required for real MJPEG streaming:

```bash
# Enable real streaming
REAL_MJPEG=true

# MJPEG stream URL
MJPEG_URL=http://192.168.1.100:8080/stream
```

### Dependencies

The web implementation requires the `web` package:

```yaml
dependencies:
  web: ^1.1.0  # For web platform compatibility
```

### Build Commands

```bash
# Test web build compatibility
flutter build web --debug

# Run web server for testing
flutter run -d web-server --web-port 8080

# Native platform builds work as usual
flutter build apk --release
```

## Platform Differences Summary

| Feature | Native (IO) | Web |
|---------|-------------|-----|
| **Stream Parsing** | Full multipart boundary detection | Browser-native handling |
| **Frame Extraction** | Direct byte array access | Canvas-based capture |
| **FPS Measurement** | Real-time calculation | Limited/estimated |
| **CORS Handling** | Not applicable | Browser security constraints |
| **Performance** | Optimal | Good with limitations |
| **Configuration** | Full timeout control | Browser-dependent |
| **Error Handling** | Detailed HTTP errors | CORS-aware errors |

## CORS Requirements (Web Only)

For web deployment, ensure your MJPEG server supports CORS:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET
Access-Control-Allow-Headers: Content-Type
```

Example nginx configuration for MJPEG server:
```nginx
location /stream {
    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods 'GET, POST, OPTIONS';
    add_header Access-Control-Allow-Headers 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range';
    
    # Proxy to your MJPEG source
    proxy_pass http://camera-server:8080/stream;
}
```

## UI States

The video UI clearly presents connection states without misleading text:

### Connection States
- **Idle**: "No stream connected" with offline icon
- **Connecting**: Spinner with "Connecting..." message  
- **Waiting**: Spinner with "Waiting for first frame..." message
- **Playing**: Video frame (real) or "Simulation Mode" indicator (fake)
- **Error**: Error icon with descriptive message and retry option

### Controls
- **Connect/Disconnect**: Changes based on current phase
- **Refresh**: Only enabled when actually playing video
- **Fullscreen**: Only enabled when playing, shows appropriate content for each phase

## Testing

### Automated Tests
```bash
# Run all video streaming tests
flutter test test/unit/video_state_test.dart test/integration/video_streaming_test.dart test/presentation/pages/video_page_test.dart

# Web-specific testing
flutter test --platform chrome  # If configured
```

### Manual Testing
See `docs/testing/mjpeg-streaming-testing-guide.md` for comprehensive manual testing procedures.

## Future Enhancements

Documented for future development:

- **TASK008**: Automatic reconnection with exponential backoff
- **TASK010**: Enhanced web parser for accurate frame counting
- FPS smoothing and frame dropping strategies
- Adaptive bitrate streaming support
- WebRTC integration for real-time communication

## Troubleshooting

### Common Issues

1. **Web UnsupportedError**: Ensure `web` package is included and conditional export is working
2. **CORS Errors**: Configure your MJPEG server to allow cross-origin requests
3. **Connection Timeouts**: Check network connectivity and server availability
4. **No Video in Simulation**: Verify `REAL_MJPEG=false` shows clear "Simulation Mode" messaging

### Debug Mode

Enable debug logging for streaming events:
```dart
// In main.dart or debug configuration
Logger.level = Level.debug;
```

---

This implementation provides robust, cross-platform MJPEG streaming with honest UI states and clear platform-specific capabilities. The phase-based model ensures predictable behavior and excellent user experience across all supported platforms.