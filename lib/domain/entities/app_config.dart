import '../../core/env.dart';

/// MQTT configuration model
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

  /// Create from environment defaults
  factory MqttConfig.fromEnv() => MqttConfig(
        host: Env.mqttHost,
        port: Env.mqttPort,
        username: Env.mqttUsername,
        password: Env.mqttPassword,
      );

  MqttConfig copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
  }) =>
      MqttConfig(
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        password: password ?? this.password,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MqttConfig &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port &&
          username == other.username &&
          password == other.password;

  @override
  int get hashCode =>
      host.hashCode ^ port.hashCode ^ username.hashCode ^ password.hashCode;
}

/// InfluxDB configuration model
class InfluxConfig {
  const InfluxConfig({
    required this.url,
    required this.token,
    required this.organization,
    required this.bucket,
  });

  final String url;
  final String token;
  final String organization;
  final String bucket;

  /// Create from environment defaults
  factory InfluxConfig.fromEnv() => InfluxConfig(
        url: Env.influxUrl,
        token: Env.influxToken,
        organization: Env.influxOrg,
        bucket: Env.influxBucket,
      );

  InfluxConfig copyWith({
    String? url,
    String? token,
    String? organization,
    String? bucket,
  }) =>
      InfluxConfig(
        url: url ?? this.url,
        token: token ?? this.token,
        organization: organization ?? this.organization,
        bucket: bucket ?? this.bucket,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InfluxConfig &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          token == other.token &&
          organization == other.organization &&
          bucket == other.bucket;

  @override
  int get hashCode =>
      url.hashCode ^
      token.hashCode ^
      organization.hashCode ^
      bucket.hashCode;
}

/// Video/MJPEG configuration model
class VideoConfig {
  const VideoConfig({
    required this.mjpegUrl,
    this.autoReconnect = true,
  });

  final String mjpegUrl;
  final bool autoReconnect;

  /// Create from environment defaults
  factory VideoConfig.fromEnv() => VideoConfig(
        mjpegUrl: Env.mjpegUrl,
      );

  VideoConfig copyWith({
    String? mjpegUrl,
    bool? autoReconnect,
  }) =>
      VideoConfig(
        mjpegUrl: mjpegUrl ?? this.mjpegUrl,
        autoReconnect: autoReconnect ?? this.autoReconnect,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoConfig &&
          runtimeType == other.runtimeType &&
          mjpegUrl == other.mjpegUrl &&
          autoReconnect == other.autoReconnect;

  @override
  int get hashCode => mjpegUrl.hashCode ^ autoReconnect.hashCode;
}

/// Complete application configuration
class AppConfig {
  const AppConfig({
    required this.mqtt,
    required this.influx,
    required this.video,
  });

  final MqttConfig mqtt;
  final InfluxConfig influx;
  final VideoConfig video;

  /// Create from environment defaults
  factory AppConfig.fromEnv() => AppConfig(
        mqtt: MqttConfig.fromEnv(),
        influx: InfluxConfig.fromEnv(),
        video: VideoConfig.fromEnv(),
      );

  AppConfig copyWith({
    MqttConfig? mqtt,
    InfluxConfig? influx,
    VideoConfig? video,
  }) =>
      AppConfig(
        mqtt: mqtt ?? this.mqtt,
        influx: influx ?? this.influx,
        video: video ?? this.video,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfig &&
          runtimeType == other.runtimeType &&
          mqtt == other.mqtt &&
          influx == other.influx &&
          video == other.video;

  @override
  int get hashCode => mqtt.hashCode ^ influx.hashCode ^ video.hashCode;
}