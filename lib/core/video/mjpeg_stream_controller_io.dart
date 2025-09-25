// Native platform implementation using dart:io HttpClient
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert' show ascii;

/// Base sealed class for events emitted by the stream controller.
sealed class FrameEvent {
  const FrameEvent(this.ts);
  final DateTime ts;
}

class StreamStarted extends FrameEvent {
  const StreamStarted(this.boundary, DateTime ts) : super(ts);
  final String boundary;
  @override
  String toString() => 'StreamStarted(boundary=$boundary)';
}

class FrameBytes extends FrameEvent {
  const FrameBytes(this.bytes, this.index, DateTime ts) : super(ts);
  final Uint8List bytes;
  final int index;
  @override
  String toString() => 'FrameBytes(index=$index, size=${bytes.length})';
}

class StreamError extends FrameEvent {
  const StreamError(this.error, this.stack, DateTime ts) : super(ts);
  final Object error;
  final StackTrace? stack;
  @override
  String toString() => 'StreamError(error=$error)';
}

class StreamEnded extends FrameEvent {
  const StreamEnded(DateTime ts, {this.reason}) : super(ts);
  final String? reason;
  @override
  String toString() => 'StreamEnded(reason=$reason)';
}

/// Configuration for MJPEG stream behavior.
class MjpegStreamConfig {
  const MjpegStreamConfig({
    this.connectTimeout = const Duration(seconds: 5),
    this.firstFrameTimeout = const Duration(seconds: 5),
    this.stallTimeout = const Duration(seconds: 5),
    this.maxFrameBytes = 2 * 1024 * 1024, // 2MB
    this.targetFps,
  });

  final Duration connectTimeout;
  final Duration firstFrameTimeout;
  final Duration stallTimeout;
  final int maxFrameBytes;
  final int? targetFps;

  MjpegStreamConfig copyWith({
    Duration? connectTimeout,
    Duration? firstFrameTimeout,
    Duration? stallTimeout,
    int? maxFrameBytes,
    int? targetFps,
  }) => MjpegStreamConfig(
    connectTimeout: connectTimeout ?? this.connectTimeout,
    firstFrameTimeout: firstFrameTimeout ?? this.firstFrameTimeout,
    stallTimeout: stallTimeout ?? this.stallTimeout,
    maxFrameBytes: maxFrameBytes ?? this.maxFrameBytes,
    targetFps: targetFps ?? this.targetFps,
  );
}

/// Native platform MJPEG stream controller using dart:io HttpClient
class MjpegStreamController {
  MjpegStreamController({MjpegStreamConfig config = const MjpegStreamConfig()})
    : _config = config;

  final MjpegStreamConfig _config;
  final _controller = StreamController<FrameEvent>.broadcast();
  HttpClient? _httpClient;
  StreamSubscription<List<int>>? _subscription;
  bool _started = false;
  int _frameIndex = 0;
  String? _boundary;
  final _buffer = BytesBuilder(copy: false);
  int _searchIndex = 0;

  Stream<FrameEvent> get events => _controller.stream;

  Future<void> start(String url, {Map<String, String>? headers}) async {
    final uri = Uri.parse(url);
    if (_started) return;
    _started = true;
    _frameIndex = 0;

    _httpClient = HttpClient();
    try {
      final req = await _httpClient!
          .getUrl(uri)
          .timeout(
            _config.connectTimeout,
            onTimeout: () {
              throw TimeoutException('Connection timeout');
            },
          );
      headers?.forEach(req.headers.add);
      final resp = await req.close();
      if (resp.statusCode >= 400) {
        throw HttpException('HTTP ${resp.statusCode}', uri: uri);
      }

      final contentType = resp.headers.contentType?.mimeType ?? '';
      final boundaryParam = resp.headers.value('content-type') ?? '';
      if (!contentType.contains('multipart/x-mixed-replace')) {
        throw StateError('Invalid content-type: $contentType');
      }
      
      final boundary = _extractBoundary(boundaryParam);
      if (boundary == null) {
        throw StateError('Boundary parameter missing');
      }
      _boundary = boundary;
      _controller.add(StreamStarted(boundary, DateTime.now()));

      _subscription = resp.listen(
        _onData,
        onError: (e, st) {
          _emitError(e, st);
        },
        onDone: () {
          _controller.add(
            StreamEnded(DateTime.now(), reason: 'HTTP stream ended'),
          );
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      _emitError(e, st);
      await stop();
    }
  }

  String? _extractBoundary(String headerValue) {
    final idx = headerValue.toLowerCase().indexOf('boundary=');
    if (idx == -1) return null;
    var b = headerValue.substring(idx + 9).trim();
    if (b.startsWith('"')) {
      final end = b.indexOf('"', 1);
      if (end != -1) b = b.substring(1, end);
    }
    if (b.startsWith('--')) b = b.substring(2);
    b = b.split(';').first.trim();
    return b.isEmpty ? null : b;
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _subscription?.cancel();
    _subscription = null;
    _httpClient?.close(force: true);
    _httpClient = null;
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

  // MJPEG multipart parsing implementation
  void _onData(List<int> chunk) {
    if (_boundary == null) return;
    _buffer.add(chunk);
    var data = _buffer.toBytes();

    final marker = ascii.encode('--$_boundary');
    int idx = _indexOf(data, marker, _searchIndex);
    while (idx != -1) {
      final headerStart = idx + marker.length;
      int partStart = headerStart;
      
      if (partStart + 1 < data.length &&
          data[partStart] == 13 &&
          data[partStart + 1] == 10) {
        partStart += 2; // Skip CRLF
      }

      // Check for terminal boundary
      if (partStart + 1 < data.length &&
          data[partStart] == 45 && /* - */
          data[partStart + 1] == 45) {
        _controller.add(
          StreamEnded(DateTime.now(), reason: 'terminal boundary'),
        );
        return;
      }

      // Parse headers
      final headersEnd = _indexOfSequence(data, const [13, 10, 13, 10], partStart);
      if (headersEnd == -1) {
        _searchIndex = idx;
        return;
      }
      
      final contentStart = headersEnd + 4;
      final nextIdx = _indexOf(data, marker, contentStart);
      if (nextIdx == -1) {
        _searchIndex = idx;
        return;
      }
      
      final frameEnd = nextIdx >= 2 ? nextIdx - 2 : contentStart;
      if (frameEnd < contentStart) {
        _searchIndex = idx;
        return;
      }
      
      final frameBytes = data.sublist(contentStart, frameEnd);
      if (frameBytes.length <= _config.maxFrameBytes) {
        _controller.add(
          FrameBytes(
            Uint8List.fromList(frameBytes),
            _frameIndex++,
            DateTime.now(),
          ),
        );
      } else {
        _emitError(
          StateError(
            'Frame size ${frameBytes.length} > max ${_config.maxFrameBytes}',
          ),
        );
      }
      
      final remaining = data.sublist(nextIdx);
      _buffer.clear();
      _buffer.add(remaining);
      _searchIndex = 0;
      data = _buffer.toBytes();
      idx = _indexOf(data, marker, 0);
    }
    final tentative = _buffer.length - marker.length;
    _searchIndex = tentative < 0 ? 0 : tentative;
  }

  int _indexOf(List<int> data, List<int> pattern, int start) {
    for (int i = start; i <= data.length - pattern.length; i++) {
      var match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  int _indexOfSequence(List<int> data, List<int> pattern, int start) =>
      _indexOf(data, pattern, start);
}