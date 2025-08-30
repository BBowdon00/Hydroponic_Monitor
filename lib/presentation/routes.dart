import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hydroponic_monitor/presentation/pages/dashboard_page.dart';
import 'package:hydroponic_monitor/presentation/pages/devices_page.dart';
import 'package:hydroponic_monitor/presentation/pages/video_page.dart';
import 'package:hydroponic_monitor/presentation/pages/charts_page.dart';
import 'package:hydroponic_monitor/presentation/pages/alerts_page.dart';
import 'package:hydroponic_monitor/presentation/pages/settings_page.dart';

/// App routes configuration
class AppRoutes {
  static const String dashboard = '/';
  static const String devices = '/devices';
  static const String video = '/video';
  static const String charts = '/charts';
  static const String alerts = '/alerts';
  static const String settings = '/settings';
}

/// Navigation destinations for bottom navigation
enum NavigationDestination {
  dashboard(
    route: AppRoutes.dashboard,
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  devices(
    route: AppRoutes.devices,
    label: 'Devices',
    icon: Icons.devices_outlined,
    selectedIcon: Icons.devices,
  ),
  video(
    route: AppRoutes.video,
    label: 'Video',
    icon: Icons.videocam_outlined,
    selectedIcon: Icons.videocam,
  ),
  charts(
    route: AppRoutes.charts,
    label: 'Charts',
    icon: Icons.analytics_outlined,
    selectedIcon: Icons.analytics,
  ),
  alerts(
    route: AppRoutes.alerts,
    label: 'Alerts',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
  ),
  settings(
    route: AppRoutes.settings,
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  );

  const NavigationDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Router configuration
final GoRouter router = GoRouter(
  initialLocation: AppRoutes.dashboard,
  routes: [
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: AppRoutes.devices,
          builder: (context, state) => const DevicesPage(),
        ),
        GoRoute(
          path: AppRoutes.video,
          builder: (context, state) => const VideoPage(),
        ),
        GoRoute(
          path: AppRoutes.charts,
          builder: (context, state) => const ChartsPage(),
        ),
        GoRoute(
          path: AppRoutes.alerts,
          builder: (context, state) => const AlertsPage(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);

/// Scaffold with bottom navigation bar
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.child});
  
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.toString();
    final selectedIndex = _getSelectedIndex(currentLocation);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          final destination = NavigationDestination.values[index];
          context.go(destination.route);
        },
        destinations: NavigationDestination.values
            .map((destination) => NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                ))
            .toList(),
      ),
    );
  }

  int _getSelectedIndex(String location) {
    final destinations = NavigationDestination.values;
    for (int i = 0; i < destinations.length; i++) {
      if (location == destinations[i].route) {
        return i;
      }
    }
    return 0; // Default to dashboard
  }
}