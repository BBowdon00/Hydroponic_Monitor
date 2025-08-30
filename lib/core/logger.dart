import 'dart:developer' as developer;

/// Structured logger for the application
class Logger {
  static const String _defaultTag = 'HydroponicMonitor';
  
  /// Log info message
  static void info(String message, {String? tag, Object? data}) {
    _log('INFO', message, tag: tag, data: data);
  }
  
  /// Log warning message  
  static void warning(String message, {String? tag, Object? data}) {
    _log('WARNING', message, tag: tag, data: data);
  }
  
  /// Log error message
  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, tag: tag, data: error);
    if (stackTrace != null) {
      developer.log(stackTrace.toString(), name: tag ?? _defaultTag);
    }
  }
  
  /// Log debug message (only in debug mode)
  static void debug(String message, {String? tag, Object? data}) {
    assert(() {
      _log('DEBUG', message, tag: tag, data: data);
      return true;
    }());
  }
  
  static void _log(String level, String message, {String? tag, Object? data}) {
    final logTag = tag ?? _defaultTag;
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '$timestamp [$level] $message';
    
    developer.log(
      logMessage,
      name: logTag,
      error: data,
    );
  }
  
  /// Redact sensitive information from logs
  static String redactSecrets(String input) {
    // Redact common secret patterns
    return input
        .replaceAllMapped(RegExp(r'password["\s]*[:=]["\s]*[^"\s,}]+', caseSensitive: false), 
            (match) => '${match.group(0)?.split(':').first}":"***redacted***"')
        .replaceAllMapped(RegExp(r'token["\s]*[:=]["\s]*[^"\s,}]+', caseSensitive: false), 
            (match) => '${match.group(0)?.split(':').first}":"***redacted***"')
        .replaceAllMapped(RegExp(r'key["\s]*[:=]["\s]*[^"\s,}]+', caseSensitive: false), 
            (match) => '${match.group(0)?.split(':').first}":"***redacted***"');
  }
}