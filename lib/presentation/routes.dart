import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'pages/sensor_page.dart';
import 'pages/devices_page.dart';
import 'pages/video_page.dart';
import 'pages/charts_page.dart';
import 'pages/settings_page.dart';
import 'widgets/connection_notification.dart';

/// Router configuration provider.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/sensor',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/sensor',
            name: 'sensor',
            builder: (context, state) => const SensorPage(),
          ),
          GoRoute(
            path: '/devices',
            name: 'devices',
            builder: (context, state) => const DevicesPage(),
          ),
          GoRoute(
            path: '/video',
            name: 'video',
            builder: (context, state) => const VideoPage(),
          ),
          GoRoute(
            path: '/charts',
            name: 'charts',
            builder: (context, state) => const ChartsPage(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
});

/// Main scaffold with bottom navigation.
class MainScaffold extends StatelessWidget {
  const MainScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ConnectionNotification(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: const MainBottomNavigation(),
    );
  }
}

/// Bottom navigation bar with all main sections.
class MainBottomNavigation extends StatelessWidget {
  const MainBottomNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.path;

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _getCurrentIndex(currentLocation),
      onTap: (index) => _onItemTapped(context, index),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.sensors), label: 'Sensor'),
        BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'Devices'),
        BottomNavigationBarItem(icon: Icon(Icons.videocam), label: 'Video'),
        BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Charts'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    );
  }

  int _getCurrentIndex(String location) {
    switch (location) {
      case '/sensor':
        return 0;
      case '/devices':
        return 1;
      case '/video':
        return 2;
      case '/charts':
        return 3;
      case '/settings':
        return 4;
      default:
        return 0;
    }
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/sensor');
        break;
      case 1:
        context.go('/devices');
        break;
      case 2:
        context.go('/video');
        break;
      case 3:
        context.go('/charts');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }
}
