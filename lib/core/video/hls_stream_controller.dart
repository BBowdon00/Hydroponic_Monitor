import 'package:video_player/video_player.dart';
import 'dart:async';

/// HLS Stream controller for H.264 video streaming.
/// Provides a unified interface for HLS playback across all platforms.
class HlsStreamController {
  VideoPlayerController? _controller;
  final _eventController = StreamController<HlsEvent>.broadcast();
  
  /// Stream of HLS events (started, error, ended, etc.)
  Stream<HlsEvent> get events => _eventController.stream;
  
  /// Whether the controller is currently active
  bool get isActive => _controller != null;
  
  /// Start HLS stream playback
  Future<void> start(String url) async {
    // Stop any existing stream first
    await stop();
    
    try {
      // Create and initialize video player controller for HLS stream
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: false,
          mixWithOthers: false,
        ),
      );
      
      // Listen for errors
      _controller!.addListener(_onPlayerChange);
      
      // Initialize the controller
      await _controller!.initialize();
      
      // Emit stream started event with resolution
      _eventController.add(HlsStreamStarted(
        width: _controller!.value.size.width,
        height: _controller!.value.size.height,
        timestamp: DateTime.now(),
      ));
      
      // Start playback
      await _controller!.play();
      
    } catch (e, stack) {
      _eventController.add(HlsStreamError(
        error: e,
        stackTrace: stack,
        timestamp: DateTime.now(),
      ));
      await stop();
    }
  }
  
  /// Stop HLS stream playback
  Future<void> stop() async {
    if (_controller != null) {
      _controller!.removeListener(_onPlayerChange);
      await _controller!.pause();
      await _controller!.dispose();
      _controller = null;
      
      _eventController.add(HlsStreamEnded(
        timestamp: DateTime.now(),
        reason: 'User stopped stream',
      ));
    }
  }
  
  /// Get the current video player controller (for rendering in UI)
  VideoPlayerController? get controller => _controller;
  
  /// Handle player state changes
  void _onPlayerChange() {
    if (_controller == null) return;
    
    final value = _controller!.value;
    
    // Check for errors
    if (value.hasError) {
      _eventController.add(HlsStreamError(
        error: value.errorDescription ?? 'Unknown error',
        stackTrace: null,
        timestamp: DateTime.now(),
      ));
    }
    
    // Check for buffer/playing state changes
    if (value.isPlaying) {
      // Stream is actively playing
      _eventController.add(HlsStreamPlaying(
        timestamp: DateTime.now(),
      ));
    } else if (value.isBuffering) {
      // Stream is buffering
      _eventController.add(HlsStreamBuffering(
        timestamp: DateTime.now(),
      ));
    }
  }
  
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
  const HlsStreamEnded({
    required super.timestamp,
    this.reason,
  });
  
  final String? reason;
}
