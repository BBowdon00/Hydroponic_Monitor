import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'core/env.dart';
import 'core/logger.dart';
import 'presentation/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration
  await Env.init();

  Logger.info('Starting Hydroponic Monitor App', tag: 'Main');

  runApp(const ProviderScope(child: HydroponicMonitorApp()));
}
