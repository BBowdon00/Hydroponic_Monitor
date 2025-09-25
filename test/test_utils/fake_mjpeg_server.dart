import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class FakeMjpegFrameSpec {
  FakeMjpegFrameSpec(this.bytes, {this.delay = Duration.zero});
  final Uint8List bytes;
  final Duration delay;
}

class FakeMjpegServer {
  FakeMjpegServer._(this._server, this.boundary);
  final HttpServer _server;
  final String boundary;

  Uri get uri => Uri.parse('http://localhost:${_server.port}/stream');

  static Future<FakeMjpegServer> start(
    List<FakeMjpegFrameSpec> frames, {
    String boundary = 'fakestream',
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.uri.path != '/stream') {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      req.response.statusCode = 200;
      req.response.headers.set(
        'Content-Type',
        'multipart/x-mixed-replace; boundary=$boundary',
      );

      for (final frame in frames) {
        if (frame.delay != Duration.zero) {
          await Future.delayed(frame.delay);
        }
        final header =
            '--$boundary\r\nContent-Type: image/jpeg\r\nContent-Length: ${frame.bytes.length}\r\n\r\n';
        req.response.add(utf8.encode(header));
        req.response.add(frame.bytes);
        req.response.add(const [13, 10]);
        await req.response.flush();
      }
      req.response.add(utf8.encode('--$boundary--\r\n'));
      await req.response.close();
    });
    return FakeMjpegServer._(server, boundary);
  }

  Future<void> stop() => _server.close();
}

Uint8List buildStubJpeg(int marker) =>
    Uint8List.fromList([0xFF, 0xD8, marker & 0xFF, 0x00, 0xFF, 0xD9]);
