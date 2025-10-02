import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/env.dart';
import 'core/logger.dart';
import 'presentation/app.dart';
import 'presentation/providers/config_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration
  await Env.init();

  // Initialize config repository
  final configRepository = await createConfigRepository();

  Logger.info('Starting Hydroponic Monitor App', tag: 'Main');

  runApp(
    ProviderScope(
      overrides: [configRepositoryProvider.overrideWithValue(configRepository)],
      child: const HydroponicMonitorApp(),
    ),
  );
}
