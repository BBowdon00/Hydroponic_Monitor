// Web platform implementation using Fetch streaming + ReadableStream parsing.
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert' show ascii;
import 'dart:js_interop'; // for .toDart conversions
import 'dart:js_util' as js_util; // promise & JS property helpers

import 'package:web/web.dart' as web;

import '../../core/logger.dart';
import 'mjpeg_stream_controller_io.dart' show FrameEvent, StreamStarted, FrameBytes, StreamError, StreamEnded, FrameResolution, MjpegStreamConfig;

/// Web MJPEG stream controller that mirrors the native (dart:io) multipart boundary
/// parsing logic using the browser Fetch API and ReadableStream. This avoids the
/// brittle <img> + <canvas> re-encode loop and provides true frame boundaries.
class MjpegStreamController {
  MjpegStreamController({MjpegStreamConfig config = const MjpegStreamConfig()}) : _config = config;

  final MjpegStreamConfig _config;
  final _controller = StreamController<FrameEvent>.broadcast();
  Stream<FrameEvent> get events => _controller.stream;

  bool _started = false;
  int _frameIndex = 0;
  String? _boundary; // boundary token (without leading --)
  final _buffer = BytesBuilder(copy: false);
  int _searchIndex = 0; // sliding search pointer to avoid rescanning
  web.AbortController? _abortController; // allows cancellation on stop()
  bool _resolutionEmitted = false;

  Future<void> start(String url, {Map<String, String>? headers}) async {
    if (_started) return;
    _started = true;
    _frameIndex = 0;
    _resolutionEmitted = false;
    _boundary = null;
    _buffer.clear();
    _searchIndex = 0;

    try {
      _abortController = web.AbortController();
      final jsHeaders = web.Headers();
      headers?.forEach((k, v) { jsHeaders.append(k, v); });
      final init = web.RequestInit(
        method: 'GET',
        headers: jsHeaders,
        signal: _abortController!.signal,
        // mode / credentials could be parameterized if needed.
      );
  Logger.info('Fetch start $url', tag: 'MJPEG_WEB');
  final resp = await web.window.fetch(url.toJS, init).toDart; // Response
      if (resp.status >= 400) {
        throw StateError('HTTP ${resp.status}');
      }
      final contentType = resp.headers.get('content-type') ?? '';
      if (!contentType.toLowerCase().contains('multipart/x-mixed-replace')) {
        throw StateError('Invalid content-type: $contentType');
      }
      _boundary = _extractBoundary(contentType);
      if (_boundary == null) {
        throw StateError('Boundary parameter missing in content-type');
      }
      _controller.add(StreamStarted(_boundary!, DateTime.now()));

      final body = resp.body;
      if (body == null) {
        throw StateError('Response has no body stream');
      }
  final reader = body.getReader();
  _pump(reader);
    } catch (e, st) {
      _emitError(e, st);
      await stop();
    }
  }

  void _pump(dynamic reader) { // dynamic due to package:web reader typing
    if (!_started) {
      try { reader.releaseLock(); } catch (_) {}
      return;
    }

    // reader.read() returns a JS Promise -> convert via promiseToFuture
    final jsPromise = reader.read();
    js_util.promiseToFuture(jsPromise).then((result) {
      if (!_started) return; // stopped while awaiting
      // Access JS object properties dynamically
      final done = js_util.getProperty(result, 'done') as bool? ?? false;
      if (done) {
        _controller.add(StreamEnded(DateTime.now(), reason: 'HTTP stream ended'));
        return;
      }
      final value = js_util.getProperty(result, 'value');
      if (value != null) {
        try {
          // Expect a Uint8Array; attempt cast to interop typed array
          final jsArray = value as JSUint8Array;
          final dartBytes = jsArray.toDart; // Uint8List
          _buffer.add(dartBytes);
          _parseBuffer();
        } catch (e, st) {
          _emitError(e, st);
        }
      }
      // Recurse for next chunk
      _pump(reader);
    }).catchError((error, stack) {
      // Ignore AbortError or post-stop noise
      final aborted = !_started || error.toString().contains('AbortError') || error.toString().contains('The operation was aborted');
      if (aborted) {
        if (_started) {
          // Treat as normal end if still marked started
          _controller.add(StreamEnded(DateTime.now(), reason: 'aborted'));
        }
        return;
      }
      _emitError(error, stack);
    });
  }

  void _parseBuffer() {
    if (_boundary == null) return;
    var data = _buffer.toBytes();
    final marker = ascii.encode('--$_boundary');
    int idx = _indexOf(data, marker, _searchIndex);
    while (idx != -1) {
      final headerStart = idx + marker.length;
      int partStart = headerStart;
      // Skip optional CRLF after boundary
      if (partStart + 1 < data.length && data[partStart] == 13 && data[partStart + 1] == 10) {
        partStart += 2;
      }
      // Terminal boundary check
      if (partStart + 1 < data.length && data[partStart] == 45 && data[partStart + 1] == 45) {
        _controller.add(StreamEnded(DateTime.now(), reason: 'terminal boundary'));
        return;
      }
      final headersEnd = _indexOfSequence(data, const [13, 10, 13, 10], partStart);
      if (headersEnd == -1) {
        _searchIndex = idx; // need more bytes
        return;
      }
      final contentStart = headersEnd + 4;
      final nextIdx = _indexOf(data, marker, contentStart);
      if (nextIdx == -1) {
        _searchIndex = idx; // wait for more
        return;
      }
      final frameEnd = nextIdx >= 2 ? nextIdx - 2 : contentStart; // trim trailing CRLF
      if (frameEnd < contentStart) {
        _searchIndex = idx;
        return;
      }
      final frameBytes = data.sublist(contentStart, frameEnd);
      if (frameBytes.length <= _config.maxFrameBytes) {
        // Emit resolution once using JPEG SOF parsing.
        if (!_resolutionEmitted) {
          final dims = _parseJpegDimensions(frameBytes);
          if (dims != null) {
            _controller.add(FrameResolution(dims.$1, dims.$2, DateTime.now()));
            _resolutionEmitted = true;
          }
        }
        _controller.add(FrameBytes(Uint8List.fromList(frameBytes), _frameIndex++, DateTime.now()));
      } else {
        _emitError(StateError('Frame size ${frameBytes.length} > max ${_config.maxFrameBytes}'));
      }
      // Remove processed bytes
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

  (int, int)? _parseJpegDimensions(List<int> bytes) {
    // Minimal JPEG SOF parser. Based on common marker scanning.
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null; // not JPEG
    int i = 2;
    while (i + 9 < bytes.length) {
      if (bytes[i] != 0xFF) {
        i++; // skip padding
        continue;
      }
      int marker = bytes[i + 1];
      if (marker == 0xD9 || marker == 0xDA) {
        break; // end / start of scan before SOF found
      }
      // Skip fill bytes FF FF ...
      while (marker == 0xFF) {
        i++;
        if (i + 1 >= bytes.length) return null;
        marker = bytes[i + 1];
      }
      // SOF0..SOF15 excluding DHT/DQT etc.
      if ((marker >= 0xC0 && marker <= 0xC3) || (marker >= 0xC5 && marker <= 0xC7) || (marker >= 0xC9 && marker <= 0xCB) || (marker >= 0xCD && marker <= 0xCF)) {
        if (i + 8 >= bytes.length) return null;
        final blockLength = (bytes[i + 2] << 8) + bytes[i + 3];
        if (blockLength < 7) return null;
        final height = (bytes[i + 5] << 8) + bytes[i + 6];
        final width = (bytes[i + 7] << 8) + bytes[i + 8];
        if (width > 0 && height > 0) return (width, height);
        return null;
      } else {
        if (i + 4 >= bytes.length) return null;
        final blockLength = (bytes[i + 2] << 8) + bytes[i + 3];
        if (blockLength < 2) return null;
        i += 2 + blockLength;
      }
    }
    return null;
  }

  String? _extractBoundary(String headerValue) {
    final lower = headerValue.toLowerCase();
    final idx = lower.indexOf('boundary=');
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
    _abortController?.abort();
    _abortController = null;
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

  int _indexOfSequence(List<int> data, List<int> pattern, int start) => _indexOf(data, pattern, start);
}