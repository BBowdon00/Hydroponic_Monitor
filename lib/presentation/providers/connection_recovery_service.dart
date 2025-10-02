import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'data_providers.dart';
import '../../core/logger.dart';

/// Simple connection recovery orchestrator. Placeholder for TASK008 expansion.
class ConnectionRecoveryService {
  ConnectionRecoveryService({required this.ref});

  final Ref ref;

  /// Force reconnection cycle for all runtime services after config save.
  Future<void> reconnectAll() async {
    Logger.info('Starting manual reconnect of services', tag: 'Recovery');

    // MQTT
    final mqtt = ref.read(mqttServiceProvider);
    await mqtt.disconnect();
    // Recreate provider (invalidate to force rebuild with new config)
    ref.invalidate(mqttServiceProvider);
    // Force instantiation & connection
    ref.read(mqttServiceProvider);

    // Influx
    final influx = ref.read(influxServiceProvider);
    await influx.close();
    ref.invalidate(influxServiceProvider);
    ref.read(influxServiceProvider); // triggers initialize

    Logger.info('Manual reconnect cycle initiated', tag: 'Recovery');
  }
}

final connectionRecoveryServiceProvider = Provider.autoDispose<ConnectionRecoveryService>((ref) {
  return ConnectionRecoveryService(ref: ref);
});