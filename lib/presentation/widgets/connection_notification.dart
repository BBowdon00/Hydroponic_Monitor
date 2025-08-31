import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/theme.dart';
import '../providers/connection_status_provider.dart';

/// A notification widget that shows connection status and disconnection timer.
class ConnectionNotification extends ConsumerStatefulWidget {
  const ConnectionNotification({super.key});

  @override
  ConsumerState<ConnectionNotification> createState() => _ConnectionNotificationState();
}

class _ConnectionNotificationState extends ConsumerState<ConnectionNotification> {
  Timer? _timer;
  String _timerText = '';

  @override
  void initState() {
    super.initState();
    // Update timer every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimer() {
    if (mounted) {
      setState(() {
        _timerText = _formatDuration();
      });
    }
  }

  String _formatDuration() {
    final connectionStatusAsync = ref.read(connectionStatusProvider);
    return connectionStatusAsync.when(
      data: (status) {
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
      },
      loading: () => '',
      error: (_, stackTrace) => '',
    );
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
                Icon(
                  Icons.wifi_off,
                  color: Colors.red.shade700,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Connection Lost',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${disconnectedServices.join(', ')} disconnected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_timerText.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSm,
                      vertical: AppTheme.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade200,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      _timerText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
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