import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/core/env.dart';
import 'package:hydroponic_monitor/core/logger.dart';
import 'package:hydroponic_monitor/presentation/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize environment configuration
  await Env.init();
  
  Logger.info('Starting Hydroponic Monitor App');
  
  runApp(
    const ProviderScope(
      child: HydroponicMonitorApp(),
    ),
  );
}