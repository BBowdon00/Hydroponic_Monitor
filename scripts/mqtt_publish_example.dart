import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

Future<void> main() async {
  // Configure MQTT broker connection
  final client = MqttServerClient('localhost', 'example_publisher');
  client.port = 1883;
  client.keepAlivePeriod = 20;
  client.logging(on: false);

  // Connect to broker
  try {
    print('Connecting to MQTT broker...');
    await client.connect();
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      print('Failed to connect: ${client.connectionStatus}');
      return;
    }
    print('Connected!');

    // Prepare sensor data payload (matches app format)
    final payload = json.encode({
      'deviceType': 'temperature',
      'deviceID': '1',
      'location': 'tent',
      'value': '23.22',
      'description': 'under light',
    });

    // Publish to topic
    final topic = 'grow/rpi/sensor';
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    print('Published to $topic: $payload');

    // Wait briefly to ensure delivery
    await Future.delayed(const Duration(seconds: 1));
    client.disconnect();
    print('Disconnected.');
  } catch (e) {
    print('Error: $e');
    client.disconnect();
  }
}
