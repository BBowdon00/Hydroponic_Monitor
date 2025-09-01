import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/theme.dart';
import '../providers/connection_status_provider.dart';

/// A notification widget that shows connection status and disconnection timer.
class ConnectionNotification extends ConsumerStatefulWidget {
  const ConnectionNotification({super.key});

  @override
  ConsumerState<ConnectionNotification> createState() =>
      _ConnectionNotificationState();
}

class _ConnectionNotificationState
    extends ConsumerState<ConnectionNotification> {
  Timer? _timer;
  Duration _currentUpdateInterval = const Duration(
    seconds: 1,
  ); // Start with 1 second
  DateTime? _lastDisconnectionTime;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_currentUpdateInterval, (_) {
      _updateTimer();
    });
  }

  void _updateTimer() {
    if (mounted) {
      setState(() {
        _updateTimerInterval();
      });
    }
  }

  void _updateTimerInterval() {
    final connectionStatusAsync = ref.read(connectionStatusProvider);
    connectionStatusAsync.when(
      data: (status) {
        final currentDisconnectionTime = status.earliestDisconnection;

        // Reset interval if disconnection time changed (new disconnection)
        if (_lastDisconnectionTime != currentDisconnectionTime) {
          _lastDisconnectionTime = currentDisconnectionTime;
          _currentUpdateInterval = const Duration(seconds: 5);
          _startTimer();
          return;
        }

        // If still disconnected, apply exponential backoff
        if (currentDisconnectionTime != null) {
          final disconnectedDuration = DateTime.now().difference(
            currentDisconnectionTime,
          );

          Duration newInterval;
          // Exponential backoff: 5s → 10s → 30s → 60s (max)
          if (disconnectedDuration.inSeconds < 30) {
            newInterval = const Duration(seconds: 5);
          } else if (disconnectedDuration.inMinutes < 2) {
            newInterval = const Duration(seconds: 10);
          } else if (disconnectedDuration.inMinutes < 10) {
            newInterval = const Duration(seconds: 30);
          } else {
            newInterval = const Duration(minutes: 1);
          }

          // Restart timer with new interval if it changed
          if (_currentUpdateInterval != newInterval) {
            _currentUpdateInterval = newInterval;
            _startTimer();
          }
        } else {
          // Connected - reset to fast updates for next disconnection
          _currentUpdateInterval = const Duration(seconds: 5);
        }
      },
      loading: () {},
      error: (_, __) {},
    );
  }

  String _formatDurationForStatus(ConnectionStatus status) {
    final disconnectionTime = status.earliestDisconnection;
    if (disconnectionTime == null) return '';

    final duration = DateTime.now().difference(disconnectionTime);

    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatusAsync = ref.watch(connectionStatusProvider);

    return connectionStatusAsync.when(
      data: (status) {
        // Don't show notification if all services are connected
        if (status.allConnected) {
          return const SizedBox.shrink();
        }

        // Build list of disconnected services
        final disconnectedServices = <String>[];
        if (!status.mqttConnected) disconnectedServices.add('MQTT');
        if (!status.influxConnected) disconnectedServices.add('InfluxDB');
        // TODO: add CameraServer status when available

        // Check if all services are disconnected
        final allServicesDisconnected =
            !status.mqttConnected && !status.influxConnected;
        final messageText = allServicesDisconnected
            ? '' // No message when all services are disconnected
            : '${disconnectedServices.join(', ')} disconnected';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceSm,
          ),
          color: Colors.red.shade100,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                SizedBox(
                  width:
                      80, // Fixed width to match timer area for perfect centering
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_off,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spaceSm),
                    ],
                  ),
                ),
                Expanded(
                  child: messageText.isEmpty
                      ? Center(
                          child: Text(
                            'Connection Lost',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Connection Lost',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              messageText,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.red.shade600),
                            ),
                            // Here I would like to keep a timer of how long the services have been disconnected
                          ],
                        ),
                ),
                if (status.earliestDisconnection != null) ...[
                  SizedBox(
                    width: 80, // Fixed width to prevent layout shifts
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSm,
                        vertical: AppTheme.spaceXs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade200,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        _formatDurationForStatus(status),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
