import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
// Only import browser client on web platforms
import 'mqtt_browser_client_stub.dart'
    if (dart.library.js) 'package:mqtt_client/mqtt_browser_client.dart';

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
    this.autoReconnect = true,
  });

  final String host;
  final int port;
  final String clientId;
  final String? username;
  final String? password;
  final bool autoReconnect;

  MqttClient? _client;
  bool _isConnecting = false;
  bool _retired =
      false; // Set when provider replaces this instance; suppress further connects
  bool get isRetired => _retired;
  int _attemptCount = 0;
  Completer<void> _initializedCompleter = Completer<void>();
  final StreamController<SensorData> _sensorDataController =
      StreamController<SensorData>.broadcast();
  final StreamController<Device> _deviceStatusController =
      StreamController<Device>.broadcast();
  // Small in-memory buffer to replay recent device status messages to
  // listeners that subscribe after messages were received (useful in tests).
  final List<Device> _deviceStatusBuffer = [];
  final StreamController<String> _connectionController =
      StreamController<String>.broadcast();
  String? _lastConnectionStatus;
  bool get _canEmitConnectionEvents =>
      !_retired && !_connectionController.isClosed;

  void _emitConnectionStatus(String status) {
    if (!_canEmitConnectionEvents) return;
    _lastConnectionStatus = status;
    try {
      _connectionController.add(status);
    } catch (_) {
      // Silently ignore if closed mid-flight.
    }
  }

  /// Stream of sensor data received via MQTT.
  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;

  /// Stream of device status updates received via MQTT.
  Stream<Device> get deviceStatusStream {
    // Return a broadcast stream that first replays buffered device messages
    // then forwards live messages from the controller.
    return Stream.multi((controller) {
      // Replay buffered items first
      for (final device in _deviceStatusBuffer) {
        controller.add(device);
      }

      // Forward live updates
      final sub = _deviceStatusController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );

      controller.onCancel = () {
        sub.cancel();
      };
    }, isBroadcast: true);
  }

  /// Stream of connection status changes.
  Stream<String> get connectionStream {
    // Replay last status to new subscribers, then forward live updates.
    return Stream.multi((controller) {
      if (_lastConnectionStatus != null) {
        controller.add(_lastConnectionStatus!);
      }

      final sub = _connectionController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );

      controller.onCancel = () => sub.cancel();
    }, isBroadcast: true);
  }

  /// Re-emit the last known connection status to listeners (useful after manual
  /// reconnect flows to force UI refresh if no transition event was observed).
  void emitCurrentStatus() {
    if (_lastConnectionStatus != null) {
      _emitConnectionStatus(_lastConnectionStatus!);
    }
  }

  /// Current connection status.
  MqttConnectionState? get connectionStatus => _client?.connectionStatus?.state;

  /// Check if client is connected.
  bool get isConnected => connectionStatus == MqttConnectionState.connected;

  // Update topic patterns to match new telegraf.conf format
  static const String _sensorTopicPattern = 'grow/+/sensor';
  static const String _actuatorTopicPattern = 'grow/+/actuator';
  static const String _deviceTopicPattern = 'grow/+/device';

  /// Stream for receiving raw MQTT messages with topic and payload
  final StreamController<HydroMqttMessage> _messageController =
      StreamController.broadcast();
  Stream<HydroMqttMessage> get messageStream => _messageController.stream;

  /// Get the current attempt count for diagnostics.
  int get attemptCount => _attemptCount;

  /// Increment and return the attempt counter.
  int incrementAttempt() => ++_attemptCount;

  /// Initialize and connect to MQTT broker.
  Future<Result<void>> connect() async {
    if (_retired) {
      Logger.debug(
        'Connect ignored on retired service (instance=${identityHashCode(this)})',
        tag: 'MQTT',
      );
      return const Success(null);
    }
    try {
      final attemptId = incrementAttempt();
      final sw = Stopwatch()..start();
      Logger.info(
        'Connecting to MQTT broker at $host:$port (attempt=$attemptId, instance=${identityHashCode(this)})',
        tag: 'MQTT',
      );

      // Prevent duplicate concurrent connect attempts or reconnect storms.
      if (_isConnecting) {
        Logger.debug(
          'Connect called while already connecting - skipping (instance=${identityHashCode(this)})',
          tag: 'MQTT',
        );
        return const Success(null);
      }

      final currentState = _client?.connectionStatus?.state;
      if (currentState == MqttConnectionState.connected) {
        Logger.debug(
          'MQTT client already connected - skipping connect (instance=${identityHashCode(this)})',
          tag: 'MQTT',
        );
        return const Success(null);
      }

      // Create appropriate client for web or server platforms
      if (kIsWeb) {
        try {
          // Support user specifying full ws:// or wss:// URL in host field. If absent, prepend ws://.
          final hasScheme =
              host.startsWith('ws://') || host.startsWith('wss://');
          final baseUrl = hasScheme ? host : 'ws://$host';
          _client = MqttBrowserClient(baseUrl, clientId);
          if (_client != null) {
            (_client as MqttBrowserClient).websocketProtocols = ['mqtt'];
            _client!.port =
                port; // Use configured port (e.g., 9001) rather than hard-coded
          }
          Logger.info(
            'Web platform detected - attempting WebSocket MQTT connection at $baseUrl:$port (instance=${identityHashCode(this)})',
            tag: 'MQTT',
          );
        } catch (e) {
          Logger.warning(
            'Failed to create web MQTT client: $e (instance=${identityHashCode(this)})',
            tag: 'MQTT',
          );
        }
      } else {
        _client = MqttServerClient.withPort(host, clientId, port);
        Logger.info(
          'Non-web platform detected - using server MQTT client (instance=${identityHashCode(this)})',
          tag: 'MQTT',
        );
      }

      if (_client == null) {
        const error = 'Failed to create MQTT client instance';
        Logger.error(error, tag: 'MQTT');
        return const Failure(MqttError(error));
      }

      // Configure client settings
      _client!.logging(on: false); // Disable verbose logging
      _client!.setProtocolV311();
      _client!.keepAlivePeriod = 20;
      _client!.connectTimeoutPeriod = 5000;
      _client!.autoReconnect = autoReconnect;

      // Set up connection callbacks
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.onUnsubscribed = _onUnsubscribed;
      _client!.onAutoReconnect = _onAutoReconnect;
      _client!.onAutoReconnected = _onAutoReconnected;

      // Set up connection message with proper authentication
      final connMess = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean();

      _client!.keepAlivePeriod = 20;

      if (username != null && password != null) {
        connMess.authenticateAs(username!, password!);
      }

      _client!.connectionMessage = connMess;

      // Attempt connection
      _isConnecting = true;
      final status = await _client!.connect();

      if (status?.state == MqttConnectionState.connected) {
        _isConnecting = false;
        Logger.info(
          'MQTT connected (attempt=$attemptId, ms=${sw.elapsedMilliseconds}, instance=${identityHashCode(this)})',
          tag: 'MQTT',
        );
        // Set up message handling
        final updates = _client!.updates;
        if (updates != null) {
          updates.listen(
            _onMessageReceived,
            onError: (error) {
              Logger.error('MQTT message stream error: $error', tag: 'MQTT');
            },
          );
        } else {
          Logger.warning('MQTT client updates stream is null', tag: 'MQTT');
        }
        await _subscribeToTopics();
        // Mark as initialized once subscriptions have been requested
        if (!_initializedCompleter.isCompleted) {
          _initializedCompleter.complete();
        }
        return const Success(null);
      } else {
        _isConnecting = false;
        final error =
            'MQTT connect failed: ${status?.state} (attempt=$attemptId, instance=${identityHashCode(this)})';
        Logger.error(error, tag: 'MQTT');
        return Failure(MqttError(error));
      }
    } catch (e, stackTrace) {
      _isConnecting = false;
      final error =
          'MQTT connect error (attempt=$attemptCount, instance=${identityHashCode(this)}): $e';
      Logger.error(error, tag: 'MQTT', error: e);
      Logger.debug('Stack trace: $stackTrace', tag: 'MQTT');
      return Failure(MqttError(error));
    }
  }

  /// Ensure the service is initialized (connected and topics subscribed).
  /// Returns once initialization completes or immediately if already initialized.
  Future<void> ensureInitialized({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_initializedCompleter.isCompleted) return;
    try {
      await _initializedCompleter.future.timeout(timeout);
    } catch (_) {
      // If timeout or error, still return to avoid test deadlocks
    }
  }

  /// Disconnect from MQTT broker.
  Future<void> disconnect() async {
    try {
      Logger.info(
        'Disconnecting from MQTT broker (instance=${identityHashCode(this)})',
        tag: 'MQTT',
      );

      // Disconnect the client
      _client?.disconnect();

      // Reset state for potential reconnection
      _isConnecting = false;

      // Emit disconnected status
      _emitConnectionStatus('disconnected');

      // Note: Don't close streams here as they may be needed for reconnection
      // Streams will be closed in dispose() method
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
    if (isConnected) {
      final subscription = _client!.subscribe(topic, MqttQos.atLeastOnce);
      if (subscription == null) {
        Logger.warning('Failed to subscribe to topic: $topic', tag: 'MQTT');
      }
    }
  }

  /// Publish a message to a topic
  Future<void> publish(String topic, String payload) async {
    if (isConnected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

      Logger.debug('Published to topic $topic: $payload', tag: 'MQTT');
    } else {
      Logger.warning('Cannot publish - MQTT client not connected', tag: 'MQTT');
    }
  }

  /// Subscribe to relevant MQTT topics using new format.
  Future<void> _subscribeToTopics() async {
    if (!isConnected) return;

    final topics = [
      _sensorTopicPattern, // grow/+/sensor
      _actuatorTopicPattern, // grow/+/actuator
      _deviceTopicPattern, // grow/+/device
    ];

    for (final topic in topics) {
      await subscribe(topic);
    }
  }

  /// Handle incoming MQTT messages.
  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      try {
        final topic = message.topic;
        final pt = message.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
          pt.payload.message,
        );

        Logger.debug('Received message on topic $topic: $payload', tag: 'MQTT');

        // Emit raw message for repository processing
        _messageController.add(
          HydroMqttMessage(topic: topic, payload: payload),
        );

        // Parse new topic format: grow/{deviceNode}/{deviceCategory}
        final topicParts = topic.split('/');
        if (topicParts.length == 3 && topicParts[0] == 'grow') {
          final deviceCategory = topicParts[2];

          switch (deviceCategory) {
            case 'sensor':
              _handleSensorData(topic, payload);
              Logger.debug('Category: Sensor', tag: 'MQTT');
              break;
            case 'actuator':
              _handleDeviceStatus(topic, payload);
              Logger.debug('Category: Actuator', tag: 'MQTT');
              break;
            case 'device':
              _handleDeviceStatus(topic, payload);
              Logger.debug('Category: Device', tag: 'MQTT');
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
    // Defensive parsing: ignore malformed JSON or unexpected payloads quietly
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        Logger.debug('Ignoring non-object sensor payload', tag: 'MQTT');
        return;
      }
      data = decoded;
    } on FormatException {
      // Malformed JSON — ignore without throwing
      Logger.debug('Malformed JSON sensor payload ignored', tag: 'MQTT');
      return;
    } catch (e) {
      Logger.debug('Unexpected sensor payload ignored: $e', tag: 'MQTT');
      return;
    }

    // Parse topic: expect grow/{deviceNode}/sensor
    final topicParts = topic.split('/');
    if (topicParts.length != 3 || topicParts[0] != 'grow') {
      Logger.debug('Unexpected sensor topic, ignoring: $topic', tag: 'MQTT');
      return;
    }

    final deviceNode = topicParts[1];

    // Required fields: deviceType and deviceID
    final deviceTypeRaw = data['deviceType'];
    final deviceIDRaw = data['deviceID'];
    final location = data['location'] as String?;

    if (deviceTypeRaw == null || deviceIDRaw == null) {
      Logger.debug(
        'Sensor payload missing deviceType/deviceID, ignoring',
        tag: 'MQTT',
      );
      return;
    }

    // Value can be numeric or string in incoming JSON
    double? value;
    final rawValue = data['value'];
    if (rawValue is num) {
      value = rawValue.toDouble();
    } else if (rawValue is String) {
      value = double.tryParse(rawValue);
    } else {
      Logger.debug(
        'Sensor payload value missing/invalid, ignoring',
        tag: 'MQTT',
      );
      return;
    }

    if (value == null) {
      Logger.debug('Sensor value parse failed, ignoring payload', tag: 'MQTT');
      return;
    }

    final deviceType = deviceTypeRaw.toString();
    final deviceID = deviceIDRaw.toString();
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

  /// Handle device status messages using new format.
  void _handleDeviceStatus(String topic, String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      Logger.debug('Parsing device status payload', tag: 'MQTT');
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
          Logger.debug(
            'Adding to deviceStatusController: $device',
            tag: 'MQTT',
          );
          // Add to in-memory buffer for late subscribers (keep last 50)
          _deviceStatusBuffer.add(device);
          if (_deviceStatusBuffer.length > 50) {
            _deviceStatusBuffer.removeAt(0);
          }

          _deviceStatusController.add(device);
        } else {
          Logger.warning(
            'Device status message missing deviceType or deviceID',
            tag: 'MQTT',
          );
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
      if (!isConnected) {
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
      await publish(topic, payloadJson);

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
    if (_retired) {
      Logger.debug(
        'Ignoring onConnected callback on retired service (instance=${identityHashCode(this)})',
        tag: 'MQTT',
      );
      return;
    }
    Logger.info('MQTT client connected', tag: 'MQTT');
    _emitConnectionStatus('connected');
  }

  void _onDisconnected() {
    if (_retired) {
      Logger.debug(
        'Ignoring onDisconnected callback on retired service (instance=${identityHashCode(this)})',
        tag: 'MQTT',
      );
      return;
    }
    Logger.warning('MQTT client disconnected', tag: 'MQTT');
    _emitConnectionStatus('disconnected');
  }

  void _onAutoReconnect() {
    Logger.info('MQTT client attempting auto-reconnection', tag: 'MQTT');
  }

  void _onAutoReconnected() {
    if (_retired) {
      Logger.debug(
        'Ignoring onAutoReconnected callback on retired service (instance=${identityHashCode(this)})',
        tag: 'MQTT',
      );
      return;
    }
    Logger.info('MQTT client auto-reconnected successfully', tag: 'MQTT');
    _emitConnectionStatus('reconnected');
    // Re-subscribe to topics after reconnection
    _subscribeToTopics();
  }

  void _onSubscribed(String topic) {
    Logger.debug('Successfully subscribed to topic: $topic', tag: 'MQTT');
  }

  void _onUnsubscribed(String? topic) {
    Logger.debug('Unsubscribed from topic: $topic', tag: 'MQTT');
  }

  /// Dispose resources (for parity with repository expectations).
  /// Reset the MQTT connection for reconnection (without closing streams).
  Future<void> reset() async {
    try {
      if (_retired) {
        Logger.debug(
          'Reset ignored on retired service (instance=${identityHashCode(this)})',
          tag: 'MQTT',
        );
        return;
      }
      Logger.info(
        'Resetting MQTT service for reconnection (instance=${identityHashCode(this)})',
        tag: 'MQTT',
      );

      // Disconnect and dispose current client
      if (_client != null) {
        _client!.disconnect();
        // Wait a moment for clean disconnect
        await Future.delayed(const Duration(milliseconds: 100));
        _client = null;
      }

      // Reset connection state
      _isConnecting = false;

      // Clear device status buffer but keep streams open
      _deviceStatusBuffer.clear();

      // Reset initialization completer for new connection
      if (_initializedCompleter.isCompleted) {
        // Create new completer for the reconnection
        _initializedCompleter = Completer<void>();
      }

      Logger.debug(
        'MQTT service reset completed (instance=${identityHashCode(this)})',
        tag: 'MQTT',
      );
    } catch (e) {
      Logger.warning('Error during MQTT reset: $e', tag: 'MQTT');
    }
  }

  Future<void> dispose() async {
    try {
      Logger.info(
        'Disposing MQTT service (instance=${identityHashCode(this)})',
        tag: 'MQTT',
      );

      // Proactively disable autoReconnect to guarantee the underlying client
      // does not schedule further websocket attempts while we tear down.
      try {
        _client?.autoReconnect = false;
      } catch (_) {}

      // Disconnect the client
      _client?.disconnect();
      _client = null;

      // Reset state
      _isConnecting = false;

      // Close all streams
      if (!_sensorDataController.isClosed) {
        await _sensorDataController.close();
      }
      if (!_deviceStatusController.isClosed) {
        await _deviceStatusController.close();
      }
      if (!_connectionController.isClosed) {
        await _connectionController.close();
      }
      if (!_messageController.isClosed) {
        await _messageController.close();
      }

      // Complete initialization completer if not already done
      if (!_initializedCompleter.isCompleted) {
        _initializedCompleter.complete();
      }
    } catch (e) {
      Logger.warning('Error during MQTT dispose: $e', tag: 'MQTT');
    }
  }

  /// Mark this service as retired so future connect/reset calls are ignored.
  void retire() {
    if (_retired) return;
    _retired = true;
    Logger.debug(
      'Retiring MQTT service (instance=${identityHashCode(this)})',
      tag: 'MQTT',
    );
    try {
      _client?.autoReconnect = false;
    } catch (_) {}
  }
}

/// Custom MQTT message container for raw topic and payload data.
class HydroMqttMessage {
  const HydroMqttMessage({required this.topic, required this.payload});

  final String topic;
  final String payload;
}
