import 'package:mqtt_client/mqtt_client.dart';

/// Stub implementation for MqttBrowserClient to avoid web imports in non-web environments

/// Stub class to prevent web import issues in non-web environments
class MqttBrowserClient extends MqttClient {
  MqttBrowserClient(super.server, super.clientIdentifier) {
    throw UnsupportedError(
      'MqttBrowserClient is only available on web platforms',
    );
  }

  @override
  set websocketProtocols(List<String> protocols) {
    throw UnsupportedError(
      'MqttBrowserClient is only available on web platforms',
    );
  }
}
