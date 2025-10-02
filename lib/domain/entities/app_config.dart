/// Application configuration model with immutable data classes.
/// Contains MQTT, InfluxDB, and MJPEG configuration.
class AppConfig {
  const AppConfig({
    required this.mqtt,
    required this.influx,
    required this.mjpeg,
  });

  final MqttConfig mqtt;
  final InfluxConfig influx;
  final MjpegConfig mjpeg;

  AppConfig copyWith({
    MqttConfig? mqtt,
    InfluxConfig? influx,
    MjpegConfig? mjpeg,
  }) {
    return AppConfig(
      mqtt: mqtt ?? this.mqtt,
      influx: influx ?? this.influx,
      mjpeg: mjpeg ?? this.mjpeg,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppConfig &&
        other.mqtt == mqtt &&
        other.influx == influx &&
        other.mjpeg == mjpeg;
  }

  @override
  int get hashCode => mqtt.hashCode ^ influx.hashCode ^ mjpeg.hashCode;

  @override
  String toString() {
    return 'AppConfig(mqtt: $mqtt, influx: $influx, mjpeg: $mjpeg)';
  }
}

/// MQTT broker configuration.
class MqttConfig {
  const MqttConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  final String host;
  final int port;
  final String username;
  final String password;

  MqttConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
  }) {
    return MqttConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MqttConfig &&
        other.host == host &&
        other.port == port &&
        other.username == username &&
        other.password == password;
  }

  @override
  int get hashCode {
    return host.hashCode ^
        port.hashCode ^
        username.hashCode ^
        password.hashCode;
  }

  @override
  String toString() {
    return 'MqttConfig(host: $host, port: $port, username: $username, password: ***)';
  }
}

/// InfluxDB configuration.
class InfluxConfig {
  const InfluxConfig({
    required this.url,
    required this.token,
    required this.org,
    required this.bucket,
  });

  final String url;
  final String token;
  final String org;
  final String bucket;

  InfluxConfig copyWith({
    String? url,
    String? token,
    String? org,
    String? bucket,
  }) {
    return InfluxConfig(
      url: url ?? this.url,
      token: token ?? this.token,
      org: org ?? this.org,
      bucket: bucket ?? this.bucket,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InfluxConfig &&
        other.url == url &&
        other.token == token &&
        other.org == org &&
        other.bucket == bucket;
  }

  @override
  int get hashCode {
    return url.hashCode ^ token.hashCode ^ org.hashCode ^ bucket.hashCode;
  }

  @override
  String toString() {
    return 'InfluxConfig(url: $url, token: ***, org: $org, bucket: $bucket)';
  }
}

/// MJPEG stream configuration.
class MjpegConfig {
  const MjpegConfig({required this.url, required this.autoReconnect});

  final String url;
  final bool autoReconnect;

  MjpegConfig copyWith({String? url, bool? autoReconnect}) {
    return MjpegConfig(
      url: url ?? this.url,
      autoReconnect: autoReconnect ?? this.autoReconnect,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MjpegConfig &&
        other.url == url &&
        other.autoReconnect == autoReconnect;
  }

  @override
  int get hashCode => url.hashCode ^ autoReconnect.hashCode;

  @override
  String toString() {
    return 'MjpegConfig(url: $url, autoReconnect: $autoReconnect)';
  }
}
