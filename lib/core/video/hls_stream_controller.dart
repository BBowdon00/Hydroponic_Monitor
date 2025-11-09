/// HLS Stream controller with platform-specific implementations.
/// 
/// On web platforms, uses an iframe to display the HTML page with hls.js
/// for Firefox/Chrome compatibility.
/// 
/// On mobile/desktop platforms, uses video_player for native HLS support.
export 'hls_stream_controller_io.dart'
    if (dart.library.html) 'hls_stream_controller_web.dart';
