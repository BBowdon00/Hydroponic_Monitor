import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponic_monitor/core/video/mjpeg_stream_controller.dart';

Future<HttpServer> _startServer(
  List<List<int>> frames, {
  String boundary = 'testboundary',
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((HttpRequest request) async {
    request.response.statusCode = 200;
    request.response.headers.set(
      'Content-Type',
      'multipart/x-mixed-replace; boundary=$boundary',
    );

    for (final frame in frames) {
      final header =
          '--$boundary\r\nContent-Type: image/jpeg\r\nContent-Length: ${frame.length}\r\n\r\n';
      request.response.add(utf8.encode(header));
      request.response.add(frame);
      request.response.add(const [13, 10]); // CRLF after frame
      await request.response.flush();
    }
    // terminating boundary
    request.response.add(utf8.encode('--$boundary--\r\n'));
    await request.response.close();
  });
  return server;
}

Uint8List _jpegStub(int seed) {
  // Minimal fake JPEG byte array (not a real decodable image but acceptable for size tests)
  // JPEG magic bytes FF D8 ... FF D9
  return Uint8List.fromList([0xFF, 0xD8, seed & 0xFF, 0xFF, 0xD9]);
}

void main() {
  group('MjpegStreamController Parser', () {
    test(
      'parses two frames successfully',
      () async {
        final frames = [_jpegStub(1).toList(), _jpegStub(2).toList()];
        final server = await _startServer(frames);
        addTearDown(() => server.close());

        final controller = MjpegStreamController();
        final events = <FrameEvent>[];
        final sub = controller.events.listen(events.add);
        addTearDown(() => sub.cancel());

        final uri = Uri.parse('http://localhost:${server.port}/stream');
        await controller.start(uri.toString());

        await Future.delayed(const Duration(milliseconds: 500));
        await controller.stop();

        // Expect a start, 2 frames, and at least one end
        expect(events.whereType<StreamStarted>().length, 1);
        expect(events.whereType<FrameBytes>().length, 2);
        expect(events.whereType<StreamEnded>().isNotEmpty, isTrue);

        final frameEvents = events.whereType<FrameBytes>().toList();
        expect(frameEvents[0].bytes.length, frames[0].length);
        expect(frameEvents[1].bytes.length, frames[1].length);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );

    test('emits error on invalid content-type', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        request.response.statusCode = 200;
        request.response.headers.set('Content-Type', 'text/plain');
        request.response.write('not a multipart stream');
        await request.response.close();
      });
      addTearDown(() => server.close());

      final controller = MjpegStreamController();
      final events = <FrameEvent>[];
      controller.events.listen(events.add);

      await controller.start('http://localhost:${server.port}/bad');
      await Future.delayed(const Duration(milliseconds: 200));

      expect(events.whereType<StreamError>().length, greaterThanOrEqualTo(1));
    });
  });
}
