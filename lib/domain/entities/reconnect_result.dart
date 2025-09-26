/// Result of a manual reconnection attempt for MQTT and InfluxDB services.
class ReconnectResult {
  const ReconnectResult({
    required this.mqttOk,
    required this.influxOk,
    required this.elapsed,
    this.errorMessage,
  });

  /// Whether the MQTT reconnection was successful.
  final bool mqttOk;

  /// Whether the InfluxDB reconnection was successful.
  final bool influxOk;

  /// Duration of the reconnection attempt.
  final Duration elapsed;

  /// Error message if either service failed to reconnect.
  final String? errorMessage;

  /// Whether both services reconnected successfully.
  bool get allOk => mqttOk && influxOk;

  /// Whether neither service reconnected successfully.
  bool get allFailed => !mqttOk && !influxOk;

  /// Whether only one service reconnected successfully.
  bool get partialSuccess => mqttOk != influxOk;

  @override
  String toString() {
    final status = allOk
        ? 'All services reconnected successfully'
        : partialSuccess
            ? 'Partial reconnection: MQTT ${mqttOk ? 'OK' : 'Failed'}, InfluxDB ${influxOk ? 'OK' : 'Failed'}'
            : 'All services failed to reconnect';
    
    return 'ReconnectResult(${status}, elapsed: ${elapsed.inMilliseconds}ms${errorMessage != null ? ', error: $errorMessage' : ''})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReconnectResult &&
        other.mqttOk == mqttOk &&
        other.influxOk == influxOk &&
        other.elapsed == elapsed &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(mqttOk, influxOk, elapsed, errorMessage);
  }
}