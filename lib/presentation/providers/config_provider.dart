import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repos/config_repository.dart';
import '../../domain/entities/app_config.dart';
import '../../core/logger.dart';

/// Provider for ConfigRepository.
final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  throw UnimplementedError('ConfigRepository provider must be overridden');
});

/// Provider for application configuration state.
/// Loads config on startup and provides methods to update it.
final configProvider =
    StateNotifierProvider<ConfigNotifier, AsyncValue<AppConfig>>((ref) {
      final repository = ref.watch(configRepositoryProvider);
      return ConfigNotifier(repository);
    });

/// Notifier for managing application configuration state.
class ConfigNotifier extends StateNotifier<AsyncValue<AppConfig>> {
  ConfigNotifier(this._repository) : super(const AsyncValue.loading()) {
    _init();
  }

  final ConfigRepository _repository;

  /// Initialize by loading config from storage.
  Future<void> _init() async {
    try {
      Logger.info('Initializing configuration provider', tag: 'ConfigNotifier');
      final config = await _repository.loadConfig();
      state = AsyncValue.data(config);
      Logger.info(
        'Configuration initialized successfully',
        tag: 'ConfigNotifier',
      );
    } catch (e, stack) {
      Logger.error(
        'Failed to initialize configuration: $e',
        tag: 'ConfigNotifier',
        error: e,
      );
      state = AsyncValue.error(e, stack);
    }
  }

  /// Update configuration and persist to storage.
  Future<void> updateConfig(AppConfig config) async {
    try {
      Logger.info('Updating configuration', tag: 'ConfigNotifier');
      await _repository.saveConfig(config);
      state = AsyncValue.data(config);
      Logger.info('Configuration updated successfully', tag: 'ConfigNotifier');
    } catch (e, stack) {
      Logger.error(
        'Failed to update configuration: $e',
        tag: 'ConfigNotifier',
        error: e,
      );
      state = AsyncValue.error(e, stack);
    }
  }

  /// Reset configuration to defaults.
  Future<void> resetToDefaults() async {
    try {
      Logger.info('Resetting configuration to defaults', tag: 'ConfigNotifier');
      await _repository.clearConfig();
      final config = await _repository.loadConfig();
      state = AsyncValue.data(config);
      Logger.info('Configuration reset successfully', tag: 'ConfigNotifier');
    } catch (e, stack) {
      Logger.error(
        'Failed to reset configuration: $e',
        tag: 'ConfigNotifier',
        error: e,
      );
      state = AsyncValue.error(e, stack);
    }
  }

  /// Reload configuration from storage.
  Future<void> reload() async {
    state = const AsyncValue.loading();
    await _init();
  }
}

/// Provider factory for ConfigRepository that handles initialization.
/// This should be used in main() to set up the config repository.
Future<ConfigRepository> createConfigRepository() async {
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final prefs = await SharedPreferences.getInstance();
  return ConfigRepository(secureStorage: secureStorage, prefs: prefs);
}
