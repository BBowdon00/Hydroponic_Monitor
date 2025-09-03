import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../../core/logger.dart';
import '../../core/errors.dart';
import '../../domain/entities/sensor_data.dart';
import '../../domain/entities/device.dart';

/// MQTT client for communicating with hydroponic system devices.
class MqttService {
  MqttService({
    required this.host,
    required this.port,
    required this.clientId,
    this.username,
    this.password,
  });

  final String host;
  final int port;
  final String clientId;
  final String? username;
  final String? password;

  MqttServerClient? _client;
  final StreamController<SensorData> _sensorDataController =
      StreamController<SensorData>.broadcast();
  final StreamController<Device> _deviceStatusController =
      StreamController<Device>.broadcast();
  final StreamController<String> _connectionController =
      StreamController<String>.broadcast();

  /// Stream of sensor data received via MQTT.
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;

  /// Stream of device status updates received via MQTT.
  Stream<Device> get deviceStatusStream => _deviceStatusController.stream;

  /// Stream of connection status changes.
  Stream<String> get connectionStream => _connectionController.stream;

  /// Current connection status.
  Object? get connectionStatus => _client?.connectionStatus;

  // Update topic patterns to match new telegraf.conf format
  static const String _sensorTopicPattern = 'grow/+/sensor';
  static const String _actuatorTopicPattern = 'grow/+/actuator';
  static const String _deviceTopicPattern = 'grow/+/device';

  /// Stream for receiving raw MQTT messages with topic and payload
  final StreamController<MqttMessage> _messageController = StreamController.broadcast();
  Stream<MqttMessage> get messageStream => _messageController.stream;

  /// Initialize and connect to MQTT broker.
  Future<Result<void>> connect() async {
    try {
      Logger.info('Connecting to MQTT broker at $host:$port', tag: 'MQTT');

      _client = MqttServerClient.withPort(host, clientId, port);
      _client!.logging(on: true);
      _client!.keepAlivePeriod = 60;
      _client!.connectTimeoutPeriod = 30000;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.onUnsubscribed = _onUnsubscribed;

      // Set up message handling
      _client!.updates!.listen(_onMessageReceived);

      // Set credentials if provided
      if (username != null && password != null) {
        _client!.connectionMessage = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .authenticateAs(username!, password!)
            .withWillTopic('grow/tent/app/status')
            .withWillMessage('OFFLINE')
            .startClean()
            .withWillQos(MqttQos.atLeastOnce);
      } else {
        _client!.connectionMessage = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .withWillTopic('grow/tent/app/status')
            .withWillMessage('OFFLINE')
            .startClean()
            .withWillQos(MqttQos.atLeastOnce);
      }

      final status = await _client!.connect();

      if (status?.toString() == 'connected') {
        Logger.info('Successfully connected to MQTT broker', tag: 'MQTT');
        await _subscribeToTopics();
        return const Success(null);
      } else {
        final error = 'Failed to connect to MQTT broker: ${status?.toString()}';
        Logger.error(error, tag: 'MQTT');
        return Failure(MqttError(error));
      }
    } catch (e) {
      final error = 'Error connecting to MQTT broker: $e';
      Logger.error(error, tag: 'MQTT', error: e);
      return Failure(MqttError(error));
    }
  }

  /// Disconnect from MQTT broker.
  Future<void> disconnect() async {
    try {
      Logger.info('Disconnecting from MQTT broker', tag: 'MQTT');
      _client?.disconnect();
      await _sensorDataController.close();
      await _deviceStatusController.close();
      await _connectionController.close();
      await _messageController.close();
    } catch (e) {
      Logger.error(
        'Error disconnecting from MQTT broker: $e',
        tag: 'MQTT',
        error: e,
      );
    }
  }

  /// Subscribe to a specific topic
  Future<void> subscribe(String topic) async {
    if (_client?.connectionStatus?.toString() == 'connected') {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      Logger.info('Subscribed to topic: $topic', tag: 'MQTT');
    }
  }

  /// Publish a message to a topic
  Future<void> publish(String topic, String payload) async {
    if (_client?.connectionStatus?.toString() == 'connected') {
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      Logger.info('Published to topic $topic: $payload', tag: 'MQTT');
    }
  }

  /// Subscribe to relevant MQTT topics using new format.
  Future<void> _subscribeToTopics() async {
    if (_client?.connectionStatus?.toString() != 'connected') return;

    final topics = [
      _sensorTopicPattern,    // grow/+/sensor
      _actuatorTopicPattern,  // grow/+/actuator
      _deviceTopicPattern,    // grow/+/device
    ];

    for (final topic in topics) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      Logger.info('Subscribed to topic: $topic', tag: 'MQTT');
    }
  }

  /// Handle incoming MQTT messages.
  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final payload = MqttPublishPayload.bytesToStringAsString(
        (message.payload as MqttPublishMessage).payload.message,
      );
      final topic = message.topic;

      Logger.debug('Received message on topic $topic: $payload', tag: 'MQTT');

      // Emit raw message for repository processing
      _messageController.add(MqttMessage(topic: topic, payload: payload));

      try {
        // Parse new topic format: grow/{deviceNode}/{deviceCategory}
        final topicParts = topic.split('/');
        if (topicParts.length == 3 && topicParts[0] == 'grow') {
          final deviceNode = topicParts[1];
          final deviceCategory = topicParts[2];

          switch (deviceCategory) {
            case 'sensor':
              _handleSensorData(topic, payload);
              break;
            case 'actuator':
              _handleDeviceStatus(topic, payload);
              break;
            case 'device':
              _handleDeviceStatus(topic, payload);
              break;
          }
        }
      } catch (e) {
        Logger.error(
          'Error processing MQTT message: $e',
          tag: 'MQTT',
          error: e,
        );
      }
    }
  }

  /// Handle sensor data messages using new format.
  void _handleSensorData(String topic, String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      
      // Parse new topic format: grow/{deviceNode}/sensor
      final topicParts = topic.split('/');
      if (topicParts.length == 3) {
        final deviceNode = topicParts[1];
        
        // Extract sensor info from payload
        final deviceType = data['deviceType'] as String?;
        final deviceID = data['deviceID'] as String?;
        final location = data['location'] as String?;
        final valueStr = data['value'] as String?;
        final description = data['description'] as String?;

        if (deviceType != null && deviceID != null && valueStr != null) {
          final value = double.tryParse(valueStr) ?? 0.0;
          final sensorType = _parseSensorType(deviceType);
          
          final sensorData = SensorData(
            id: '${deviceNode}_${deviceType}_$deviceID',
            sensorType: sensorType,
            value: value,
            unit: sensorType.defaultUnit,
            timestamp: DateTime.now(),
            deviceId: deviceNode,
            location: location,
          );
          
          _sensorDataController.add(sensorData);
        }
      }
    } catch (e) {
      Logger.error('Error parsing sensor data: $e', tag: 'MQTT', error: e);
    }
  }

  /// Handle device status messages using new format.
  void _handleDeviceStatus(String topic, String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      
      // Parse new topic format: grow/{deviceNode}/{actuator|device}
      final topicParts = topic.split('/');
      if (topicParts.length == 3) {
        final deviceNode = topicParts[1];
        final deviceCategory = topicParts[2];
        
        // Extract device info from payload
        final deviceType = data['deviceType'] as String?;
        final deviceID = data['deviceID'] as String?;
        final location = data['location'] as String?;
        final running = data['running'] as bool?;
        final description = data['description'] as String?;

        if (deviceType != null && deviceID != null) {
          final device = Device(
            id: '${deviceNode}_${deviceType}_$deviceID',
            name: description ?? '$deviceType $deviceID',
            type: _parseDeviceType(deviceType),
            status: running == true ? DeviceStatus.online : DeviceStatus.offline,
            location: location,
            isEnabled: running ?? false,
            lastUpdate: DateTime.now(),
          );
          
          _deviceStatusController.add(device);
        }
      }
    } catch (e) {
      Logger.error('Error parsing device status: $e', tag: 'MQTT', error: e);
    }
  }

  /// Parse sensor type from string.
  SensorType _parseSensorType(String typeString) {
    for (final type in SensorType.values) {
      if (type.name.toLowerCase() == typeString.toLowerCase()) {
        return type;
      }
    }
    return SensorType.temperature; // Default fallback
  }

  /// Parse device type from string.
  DeviceType _parseDeviceType(String typeString) {
    for (final type in DeviceType.values) {
      if (type.name.toLowerCase() == typeString.toLowerCase()) {
        return type;
      }
    }
    return DeviceType.pump; // Default fallback
  }

  String _buildSensorTopic(String deviceNode) {
    return 'grow/$deviceNode/sensor';
  }

  String _buildActuatorTopic(String deviceNode) {
    return 'grow/$deviceNode/actuator';
  }

  String _buildDeviceTopic(String deviceNode) {
    return 'grow/$deviceNode/device';
  }

  Map<String, dynamic> _buildSensorPayload(SensorData data) {
    return {
      'deviceType': data.sensorType.name,
      'deviceID': data.id,
      'location': data.location ?? 'default',
      'value': data.value.toString(), // String format for telegraf
      'description': 'Sensor reading from ${data.sensorType.name}',
    };
  }

  Map<String, dynamic> _buildActuatorPayload(Device device, bool running) {
    return {
      'deviceType': device.type.name,
      'deviceID': device.id,
      'location': device.location ?? 'default',
      'running': running,
      'description': '${device.name} actuator state',
    };
  }

  void _onConnected() {
    Logger.info('MQTT client connected', tag: 'MQTT');
  }

  void _onDisconnected() {
    Logger.warning('MQTT client disconnected', tag: 'MQTT');
    _connectionController.add('disconnected');
  }

  void _onSubscribed(String topic) {
    Logger.info('Subscribed to topic: $topic', tag: 'MQTT');
  }

  void _onUnsubscribed(String? topic) {
    Logger.info('Unsubscribed from topic: $topic', tag: 'MQTT');
  }
}

/// MQTT message container for raw topic and payload data.
class MqttMessage {
  const MqttMessage({required this.topic, required this.payload});
  
  final String topic;
  final String payload;
}
  Map<String, dynamic> _buildSensorPayload(SensorData data) {
    return {
      'deviceType': data.sensorType.name,
      'deviceID': data.id,
      'location': data.location ?? 'default',
      'value': data.value.toString(), // String format for telegraf
      'description': 'Sensor reading from ${data.sensorType.name}',
    };
  }

  Map<String, dynamic> _buildActuatorPayload(Device device, bool running) {
    return {
      'deviceType': device.type.name,
      'deviceID': device.id,
      'location': device.location ?? 'default',
      'running': running,
      'description': '${device.name} actuator state',
    };
  }

  void _onConnected() {
    Logger.info('MQTT client connected', tag: 'MQTT');
    _connectionController.add('connected');
  }

  void _onDisconnected() {
    Logger.warning('MQTT client disconnected', tag: 'MQTT');
    _connectionController.add('disconnected');
  }

  void _onSubscribed(String topic) {
    Logger.info('Subscribed to topic: $topic', tag: 'MQTT');
  }

  void _onUnsubscribed(String? topic) {
    Logger.info('Unsubscribed from topic: $topic', tag: 'MQTT');
  }
}

/// MQTT message container for raw topic and payload data.
class MqttMessage {
  const MqttMessage({required this.topic, required this.payload});
  
  final String topic;
  final String payload;
}
