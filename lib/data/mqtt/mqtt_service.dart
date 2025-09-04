import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as Math;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

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

  MqttClient? _client;
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
  final StreamController<HydroMqttMessage> _messageController =
      StreamController.broadcast();
  Stream<HydroMqttMessage> get messageStream => _messageController.stream;

  /// Initialize and connect to MQTT broker.
  Future<Result<void>> connect() async {
    try {
      Logger.info('Connecting to MQTT broker at $host:$port', tag: 'MQTT');

      // For web platform, provide mock data instead of trying MQTT connection
      if (kIsWeb) {
        Logger.info('Web platform detected - using mock MQTT data for demo', tag: 'MQTT');
        _connectionController.add('connected');
        
        // Start mock data simulation
        _startMockDataSimulation();
        
        return const Success(null);
      }

      // Create server client for non-web platforms
      _client = MqttServerClient.withPort(host, clientId, port);
      
      if (_client == null) {
        const error = 'Failed to create MQTT client instance';
        Logger.error(error, tag: 'MQTT');
        return const Failure(MqttError(error));
      }

      _client!.logging(on: true);
      _client!.keepAlivePeriod = 60;
      _client!.connectTimeoutPeriod = 30000;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.onUnsubscribed = _onUnsubscribed;

      // Set up message handling - using mqtt_client's MqttMessage type
      final updates = _client!.updates;
      if (updates != null) {
        updates.listen(_onMessageReceived);
      } else {
        Logger.warning('MQTT client updates stream is null', tag: 'MQTT');
      }

      // Set credentials if provided
      if (username != null && password != null) {
        _client!.connectionMessage = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .authenticateAs(username!, password!)
            .withWillTopic('grow/app/device')
            .withWillMessage('OFFLINE')
            .startClean()
            .withWillQos(MqttQos.atLeastOnce);
      } else {
        _client!.connectionMessage = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .withWillTopic('grow/app/device')
            .withWillMessage('OFFLINE')
            .startClean()
            .withWillQos(MqttQos.atLeastOnce);
      }

      Logger.info('Attempting to connect to MQTT broker...', tag: 'MQTT');
      final status = await _client!.connect();

      Logger.info('MQTT connection attempt complete. Status: ${status?.toString()}', tag: 'MQTT');

      if (status?.toString() == 'connected') {
        Logger.info('Successfully connected to MQTT broker', tag: 'MQTT');
        await _subscribeToTopics();
        return const Success(null);
      } else {
        final error = 'Failed to connect to MQTT broker: ${status?.toString()}';
        Logger.error(error, tag: 'MQTT');
        return Failure(MqttError(error));
      }
    } catch (e, stackTrace) {
      final error = 'Error connecting to MQTT broker: $e';
      Logger.error(error, tag: 'MQTT', error: e);
      Logger.debug('Stack trace: $stackTrace', tag: 'MQTT');
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
      _sensorTopicPattern, // grow/+/sensor
      _actuatorTopicPattern, // grow/+/actuator
      _deviceTopicPattern, // grow/+/device
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
      _messageController.add(HydroMqttMessage(topic: topic, payload: payload));

      try {
        // Parse new topic format: grow/{deviceNode}/{deviceCategory}
        final topicParts = topic.split('/');
        if (topicParts.length == 3 && topicParts[0] == 'grow') {
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
            status: running == true
                ? DeviceStatus.online
                : DeviceStatus.offline,
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

  /// Publish a device command using the new topic format.
  Future<Result<void>> publishDeviceCommand(
    String deviceId,
    String command, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      if (_client?.connectionStatus?.toString() != 'connected') {
        return const Failure(MqttError('MQTT client not connected'));
      }

      // Parse device ID to extract device node
      final deviceIdParts = deviceId.split('_');
      final deviceNode = deviceIdParts.isNotEmpty ? deviceIdParts[0] : 'rpi';

      // Build command topic using new format: grow/{deviceNode}/actuator/set
      final topic = 'grow/$deviceNode/actuator/set';

      // Build command payload
      final payload = {
        'deviceID': deviceId,
        'command': command,
        if (parameters != null) ...parameters,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      final payloadJson = jsonEncode(payload);
      final builder = MqttClientPayloadBuilder();
      builder.addString(payloadJson);

      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

      Logger.info(
        'Published device command to topic $topic: $payloadJson',
        tag: 'MQTT',
      );

      return const Success(null);
    } catch (e) {
      final error = 'Error publishing device command: $e';
      Logger.error(error, tag: 'MQTT', error: e);
      return Failure(MqttError(error));
    }
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

  /// Start mock data simulation for web platform
  void _startMockDataSimulation() {
    Logger.info('Starting mock MQTT data simulation for web demo', tag: 'MQTT');
    
    // Generate mock sensor data every 5 seconds
    Timer.periodic(const Duration(seconds: 5), (timer) {
      final now = DateTime.now();
      final sensorTypes = [
        SensorType.temperature,
        SensorType.humidity,
        SensorType.pH,
        SensorType.waterLevel,
        SensorType.electricalConductivity,
        SensorType.powerUsage,
      ];
      
      for (final sensorType in sensorTypes) {
        final sensorData = _generateMockSensorData(sensorType, now);
        _sensorDataController.add(sensorData);
      }
    });
    
    // Generate mock device status every 10 seconds
    Timer.periodic(const Duration(seconds: 10), (timer) {
      final devices = [
        Device(
          id: 'water_pump_1',
          name: 'Water Pump',
          type: DeviceType.pump,
          status: DeviceStatus.online,
          isEnabled: DateTime.now().second % 2 == 0,
          lastUpdate: DateTime.now(),
        ),
        Device(
          id: 'fan_1',
          name: 'Fan 1',
          type: DeviceType.fan,
          status: DeviceStatus.online,
          isEnabled: DateTime.now().second % 3 == 0,
          lastUpdate: DateTime.now(),
        ),
        Device(
          id: 'led_lights_1',
          name: 'LED Lights',
          type: DeviceType.light,
          status: DeviceStatus.online,
          isEnabled: true,
          lastUpdate: DateTime.now(),
        ),
      ];
      
      for (final device in devices) {
        _deviceStatusController.add(device);
      }
    });
  }

  SensorData _generateMockSensorData(SensorType type, DateTime timestamp) {
    final random = Math.Random();
    double value;
    switch (type) {
      case SensorType.temperature:
        value = 18.0 + (random.nextDouble() * 12.0); // 18-30°C
        break;
      case SensorType.humidity:
        value = 40.0 + (random.nextDouble() * 40.0); // 40-80%
        break;
      case SensorType.pH:
        value = 5.5 + (random.nextDouble() * 2.0); // 5.5-7.5 pH
        break;
      case SensorType.waterLevel:
        value = 20.0 + (random.nextDouble() * 60.0); // 20-80%
        break;
      case SensorType.electricalConductivity:
        value = 800.0 + (random.nextDouble() * 400.0); // 800-1200 μS/cm
        break;
      case SensorType.powerUsage:
        value = 50.0 + (random.nextDouble() * 200.0); // 50-250W
        break;
      case SensorType.lightIntensity:
        value = 100.0 + (random.nextDouble() * 500.0); // 100-600 lux
        break;
      case SensorType.airQuality:
        value = 200.0 + (random.nextDouble() * 300.0); // 200-500 ppm
        break;
    }
    
    return SensorData(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      deviceId: 'rpi',
      sensorType: type,
      value: value,
      unit: type.defaultUnit,
      timestamp: timestamp,
    );
  }
}

/// Custom MQTT message container for raw topic and payload data.
class HydroMqttMessage {
  const HydroMqttMessage({required this.topic, required this.payload});

  final String topic;
  final String payload;
}
