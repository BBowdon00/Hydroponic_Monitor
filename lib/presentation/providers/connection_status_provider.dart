import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'system_providers.dart';
import '../../data/services/data_service.dart' as data_service;

// Re-export the ConnectionState class for backwards compatibility
export '../../data/services/data_service.dart' show ConnectionState;

/// Provider that tracks connection status for all data services.
/// This is a simplified version that uses the unified DataService.
final connectionStatusProvider = StreamProvider<data_service.ConnectionState>((ref) {
  final dataService = ref.read(dataServiceProvider);
  return dataService.connectionStream;
});

/// Legacy compatibility type alias.
typedef ConnectionStatus = data_service.ConnectionState;
