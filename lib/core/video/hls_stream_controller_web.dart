import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import '../logger.dart';

/// HLS Stream controller for web platform.
/// Uses an iframe to display the HLS HTML page with hls.js for Firefox/Chrome compatibility.
class HlsStreamController {
  String? _currentUrl;
  String? _viewId;
  final _eventController = StreamController<HlsEvent>.broadcast();

  /// Stream of HLS events (started, error, ended, etc.)
  Stream<HlsEvent> get events => _eventController.stream;

  /// Whether the controller is currently active
  bool get isActive => _currentUrl != null;

  /// Start HLS stream playback
  Future<void> start(String url) async {
    // Stop any existing stream first
    await stop();

    try {
      Logger.info('Starting HLS stream from URL: $url', tag: 'HlsController');

      // For web, use the root URL (remove /stream.m3u8) to get the HTML page with embedded player
      final uri = Uri.parse(url);
      final baseUrl = '${uri.scheme}://${uri.host}:${uri.port}';

      Logger.info('Using base URL for iframe: $baseUrl', tag: 'HlsController');

      // Generate unique view ID
      _viewId = 'hls-iframe-${DateTime.now().millisecondsSinceEpoch}';
      _currentUrl = baseUrl;

      // Create iframe element
      final iframe = html.IFrameElement()
        ..src = baseUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;

      // Register the view factory
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId!,
        (int viewId) => iframe,
      );

      Logger.info(
        'HLS iframe registered with view ID: $_viewId',
        tag: 'HlsController',
      );

      // Emit stream started event
      // Since we're using iframe, we don't know the actual video resolution
      // Use default 16:9 aspect ratio
      _eventController.add(
        HlsStreamStarted(width: 1280, height: 720, timestamp: DateTime.now()),
      );

      // Simulate playing state after a short delay to allow iframe to load
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_currentUrl != null) {
          _eventController.add(HlsStreamPlaying(timestamp: DateTime.now()));
        }
      });
    } catch (e, stack) {
      Logger.error(
        'Failed to start HLS stream: $e',
        tag: 'HlsController',
        error: e,
      );
      _eventController.add(
        HlsStreamError(error: e, stackTrace: stack, timestamp: DateTime.now()),
      );
      await stop();
    }
  }

  /// Stop HLS stream playback
  Future<void> stop() async {
    if (_currentUrl != null) {
      Logger.info('Stopping HLS stream', tag: 'HlsController');
      _currentUrl = null;
      _viewId = null;

      _eventController.add(
        HlsStreamEnded(
          timestamp: DateTime.now(),
          reason: 'User stopped stream',
        ),
      );
    }
  }

  /// Get the view ID for the platform view
  String? get viewId => _viewId;

  /// Get the video player controller (only used on mobile, returns null on web)
  dynamic get controller => null;

  /// Dispose of resources
  void dispose() {
    stop();
    _eventController.close();
  }
}

/// Base class for HLS stream events
sealed class HlsEvent {
  const HlsEvent({required this.timestamp});
  final DateTime timestamp;
}

/// Event emitted when stream starts successfully
class HlsStreamStarted extends HlsEvent {
  const HlsStreamStarted({
    required this.width,
    required this.height,
    required super.timestamp,
  });

  final double width;
  final double height;
}

/// Event emitted when stream is playing
class HlsStreamPlaying extends HlsEvent {
  const HlsStreamPlaying({required super.timestamp});
}

/// Event emitted when stream is buffering
class HlsStreamBuffering extends HlsEvent {
  const HlsStreamBuffering({required super.timestamp});
}

/// Event emitted when stream encounters an error
class HlsStreamError extends HlsEvent {
  const HlsStreamError({
    required this.error,
    required this.stackTrace,
    required super.timestamp,
  });

  final Object error;
  final StackTrace? stackTrace;
}

/// Event emitted when stream ends
class HlsStreamEnded extends HlsEvent {
  const HlsStreamEnded({required super.timestamp, this.reason});

  final String? reason;
}
