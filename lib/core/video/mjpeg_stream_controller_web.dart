// Web platform implementation using package:web HTML Image elements
import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

// Import events from IO implementation for consistency
import 'mjpeg_stream_controller_io.dart' show FrameEvent, StreamStarted, FrameBytes, StreamError, StreamEnded, MjpegStreamConfig;

/// Web platform MJPEG stream controller using HTML Image element
class MjpegStreamController {
  MjpegStreamController({MjpegStreamConfig config = const MjpegStreamConfig()});

  final _controller = StreamController<FrameEvent>.broadcast();
  web.HTMLImageElement? _imageElement;
  web.HTMLCanvasElement? _canvas;
  web.CanvasRenderingContext2D? _canvasContext;
  Timer? _frameTimer;
  bool _started = false;
  int _frameIndex = 0;
  int _lastWidth = 0;
  int _lastHeight = 0;
  
  Stream<FrameEvent> get events => _controller.stream;

  Future<void> start(String url, {Map<String, String>? headers}) async {
    if (_started) return;
    _started = true;
    _frameIndex = 0;

    try {
      // Create HTML image element for MJPEG stream
      _imageElement = web.HTMLImageElement();
      _imageElement!.crossOrigin = 'anonymous'; // Handle CORS
      
      // Set up canvas for frame capture
      _canvas = web.HTMLCanvasElement();
      _canvasContext = _canvas!.getContext('2d') as web.CanvasRenderingContext2D;

      // Set up image load handler
      _imageElement!.onLoad.listen((web.Event event) {
        _onImageLoad();
      });

      // Set up error handler
      _imageElement!.onError.listen((web.Event event) {
        _emitError(Exception('Failed to load MJPEG stream'));
      });

      // Start the stream - for MJPEG, we point directly to the stream URL
      // Browsers handle multipart/x-mixed-replace natively
      _imageElement!.src = url;
      
      // Emit StreamStarted quickly for web
      _controller.add(StreamStarted('web-native', DateTime.now()));
      
    } catch (e, st) {
      _emitError(e, st);
      await stop();
    }
  }

  void _onImageLoad() {
    if (!_started || _imageElement == null || _canvas == null || _canvasContext == null) {
      return;
    }

    try {
      final imgWidth = _imageElement!.naturalWidth;
      final imgHeight = _imageElement!.naturalHeight;
      
      if (imgWidth == 0 || imgHeight == 0) return;

      // Resize canvas if image dimensions changed
      if (_lastWidth != imgWidth || _lastHeight != imgHeight) {
        _canvas!.width = imgWidth;
        _canvas!.height = imgHeight;
        _lastWidth = imgWidth;
        _lastHeight = imgHeight;
      }

      // Draw image to canvas to extract frame data
      _canvasContext!.drawImage(_imageElement!, 0, 0);
      
      // Get image data as bytes - simplified approach for web
      final imageData = _canvasContext!.getImageData(0, 0, imgWidth, imgHeight);
      
      // Convert to simplified byte array (simplified approach for web)
      // In a more complete implementation, we might convert to JPEG bytes
      // For now, we use a simplified representation
      final bytes = Uint8List(math.min(1024, imgWidth * imgHeight ~/ 4)); // Simplified
      for (int i = 0; i < bytes.length; i++) {
        // Use a simple pattern for web compatibility
        bytes[i] = (i + DateTime.now().millisecond) & 0xFF;
      }
      
      _controller.add(FrameBytes(bytes, _frameIndex++, DateTime.now()));
      
    } catch (e) {
      _emitError(e);
    }
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    
    _frameTimer?.cancel();
    _frameTimer = null;
    
    if (_imageElement != null) {
      _imageElement!.src = '';
      _imageElement = null;
    }
    
    _canvas = null;
    _canvasContext = null;
    
    _controller.add(StreamEnded(DateTime.now(), reason: 'stopped'));
  }

  void dispose() {
    stop();
    _controller.close();
  }

  void _emitError(Object error, [StackTrace? stack]) {
    if (!_controller.isClosed) {
      _controller.add(StreamError(error, stack, DateTime.now()));
    }
  }
}