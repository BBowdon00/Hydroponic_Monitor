/// Stub implementation for MqttBrowserClient to avoid web imports in non-web environments
import 'package:mqtt_client/mqtt_client.dart';

/// Stub class to prevent web import issues in non-web environments
class MqttBrowserClient extends MqttClient {
  MqttBrowserClient(String server, String clientIdentifier) : super(server, clientIdentifier) {
    throw UnsupportedError('MqttBrowserClient is only available on web platforms');
  }
  
  set websocketProtocols(List<String> protocols) {
    throw UnsupportedError('MqttBrowserClient is only available on web platforms');
  }
}