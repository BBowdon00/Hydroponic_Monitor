import 'dart:developer' as developer;

/// Simple logger for the application.
/// Uses structured logging with feature tags.
class Logger {
  static const String _appName = 'HydroponicMonitor';
  static bool _isTest = false;

  /// Initialize the logger.
  static void init({bool isTest = false}) {
    _isTest = isTest;
    if (_isTest) {
      info('Logger initialized in test mode');
    }
  }

  /// Log info message.
  static void info(String message, {String? tag}) {
    _log('INFO', message, tag: tag);
  }

  /// Log warning message.
  static void warning(String message, {String? tag}) {
    _log('WARNING', message, tag: tag);
  }

  /// Log error message.
  static void error(String message, {String? tag, Object? error}) {
    _log('ERROR', message, tag: tag);
    if (error != null) {
      developer.log(
        'Error details: $error',
        name: '$_appName:${tag ?? 'Unknown'}',
        level: 1000,
      );
    }
  }

  /// Log debug message (only in debug mode).
  static void debug(String message, {String? tag}) {
    assert(() {
      _log('DEBUG', message, tag: tag);
      return true;
    }());
  }

  static void _log(String level, String message, {String? tag}) {
    final tagStr = tag != null ? ':$tag' : '';

    if (_isTest) {
      // In test mode, use print to ensure output is visible
      // ignore: avoid_print
      print('[$_appName$tagStr] [$level] $message');
    }

    developer.log('[$level] $message', name: '$_appName$tagStr');
  }
}
