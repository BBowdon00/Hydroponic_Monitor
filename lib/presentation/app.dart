import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hydroponic_monitor/core/theme.dart';
import 'package:hydroponic_monitor/presentation/routes.dart';

/// Main application widget
class HydroponicMonitorApp extends ConsumerWidget {
  const HydroponicMonitorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Hydroponic Monitor',
      debugShowCheckedModeBanner: false,
      
      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      
      // Router configuration
      routerConfig: router,
      
      // Accessibility and localization support
      builder: (context, child) {
        return MediaQuery(
          // Ensure text scales properly
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.of(context).textScaler.clamp(
              minScaleFactor: 0.8,
              maxScaleFactor: 1.5,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}