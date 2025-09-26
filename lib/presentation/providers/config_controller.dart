import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/errors.dart';
import '../../core/logger.dart';
import '../../domain/entities/app_config.dart';
import '../../data/repos/config_repository.dart';
import '../../data/mqtt/mqtt_service.dart';
import '../../data/influx/influx_service.dart';

/// Configuration controller that manages app configuration state
class ConfigController extends AutoDisposeAsyncNotifier<AppConfig> {
  ConfigRepository? _repository;
  StreamSubscription<AppConfig>? _configSubscription;
  Timer? _debounceTimer;

  @override
  Future<AppConfig> build() async {
    Logger.info('Initializing ConfigController', tag: 'ConfigController');
    
    _repository = ref.watch(configRepositoryProvider);
    
    // Listen for configuration changes from repository
    _configSubscription = _repository!.configStream.listen((config) {
      if (state.hasValue && state.value != config) {
        Logger.info('Configuration changed, updating state', tag: 'ConfigController');
        state = AsyncValue.data(config);
      }
    });

    // Load initial configuration
    final config = await _repository!.getConfig();
    Logger.info('ConfigController initialized with config', tag: 'ConfigController');
    
    // Cleanup on dispose
    ref.onDispose(() {
      _configSubscription?.cancel();
      _debounceTimer?.cancel();
    });
    
    return config;
  }

  /// Update MQTT configuration
  Future<void> updateMqttConfig(MqttConfig mqttConfig) async {
    await _updateConfigSection((config) => config.copyWith(mqtt: mqttConfig));
  }

  /// Update InfluxDB configuration
  Future<void> updateInfluxConfig(InfluxConfig influxConfig) async {
    await _updateConfigSection((config) => config.copyWith(influx: influxConfig));
  }

  /// Update video configuration
  Future<void> updateVideoConfig(VideoConfig videoConfig) async {
    await _updateConfigSection((config) => config.copyWith(video: videoConfig));
  }

  /// Update complete configuration
  Future<void> updateConfig(AppConfig newConfig) async {
    state = const AsyncValue.loading();
    
    try {
      Logger.info('Updating complete configuration', tag: 'ConfigController');
      await _repository!.updateConfig(newConfig);
      state = AsyncValue.data(newConfig);
      Logger.info('Complete configuration updated successfully', tag: 'ConfigController');
    } catch (error, stackTrace) {
      Logger.error('Failed to update complete configuration: $error',
          tag: 'ConfigController', error: error);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Reset configuration to environment defaults
  Future<void> resetToDefaults() async {
    state = const AsyncValue.loading();
    
    try {
      Logger.info('Resetting configuration to defaults', tag: 'ConfigController');
      await _repository!.resetToDefaults();
      final defaultConfig = AppConfig.fromEnv();
      state = AsyncValue.data(defaultConfig);
      Logger.info('Configuration reset to defaults successfully', tag: 'ConfigController');
    } catch (error, stackTrace) {
      Logger.error('Failed to reset configuration to defaults: $error',
          tag: 'ConfigController', error: error);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Test MQTT connection without persisting configuration
  Future<Result<void>> testMqttConnection(MqttConfig config) async {
    try {
      Logger.info('Testing MQTT connection', tag: 'ConfigController');
      
      final mqttService = MqttService(
        host: config.host,
        port: config.port,
        clientId: 'hydroponic_monitor_test_${DateTime.now().millisecondsSinceEpoch}',
        username: config.username.isNotEmpty ? config.username : null,
        password: config.password.isNotEmpty ? config.password : null,
        autoReconnect: false,
      );

      final result = await mqttService.connect();
      if (result is Success) {
        // Disconnect immediately after successful test
        await mqttService.disconnect();
        Logger.info('MQTT connection test successful', tag: 'ConfigController');
      } else {
        Logger.warning('MQTT connection test failed: ${result.when(
          success: (_) => 'Unknown',
          failure: (error) => error.toString(),
        )}', tag: 'ConfigController');
      }
      
      return result;
    } catch (error) {
      Logger.error('MQTT connection test error: $error',
          tag: 'ConfigController', error: error);
      return Failure(UnknownError('MQTT test failed: $error'));
    }
  }

  /// Test InfluxDB connection without persisting configuration
  Future<Result<void>> testInfluxConnection(InfluxConfig config) async {
    try {
      Logger.info('Testing InfluxDB connection', tag: 'ConfigController');
      
      final influxService = InfluxDbService(
        url: config.url,
        token: config.token,
        organization: config.organization,
        bucket: config.bucket,
      );

      final result = await influxService.initialize();
      if (result is Success) {
        // Close connection immediately after successful test
        await influxService.close();
        Logger.info('InfluxDB connection test successful', tag: 'ConfigController');
      } else {
        Logger.warning('InfluxDB connection test failed: ${result.when(
          success: (_) => 'Unknown',
          failure: (error) => error.toString(),
        )}', tag: 'ConfigController');
      }
      
      return result;
    } catch (error) {
      Logger.error('InfluxDB connection test error: $error',
          tag: 'ConfigController', error: error);
      return Failure(UnknownError('InfluxDB test failed: $error'));
    }
  }

  /// Helper to update a section of configuration with debouncing
  Future<void> _updateConfigSection(AppConfig Function(AppConfig) updater) async {
    if (!state.hasValue) return;

    // Cancel previous debounce timer
    _debounceTimer?.cancel();
    
    // Debounce rapid updates
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!state.hasValue) return;

      final currentConfig = state.value!;
      final newConfig = updater(currentConfig);
      
      // Only update if config actually changed
      if (newConfig != currentConfig) {
        await updateConfig(newConfig);
      }
    });
  }
}

/// Provider for configuration repository
final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  final repository = ConfigRepository();
  ref.onDispose(() => repository.dispose());
  return repository;
});

/// Provider for configuration controller
final configControllerProvider = AutoDisposeAsyncNotifierProvider<ConfigController, AppConfig>(() {
  return ConfigController();
});

/// Helper extensions for working with Result types
extension ConfigResultExt<T> on Result<T> {
  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) failure,
  }) {
    if (this is Success<T>) {
      return success((this as Success<T>).data);
    } else {
      return failure((this as Failure<T>).error);
    }
  }
}