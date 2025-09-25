// Platform-conditional MJPEG stream controller export
// Provides unified API across platforms with platform-specific implementations

// Export the appropriate implementation based on platform
export 'mjpeg_stream_controller_io.dart'
  if (dart.library.html) 'mjpeg_stream_controller_web.dart';

// Ensure FrameEvent types are always available regardless of platform  
export 'mjpeg_stream_controller_io.dart' show FrameEvent, StreamStarted, FrameBytes, StreamError, StreamEnded, MjpegStreamConfig;
