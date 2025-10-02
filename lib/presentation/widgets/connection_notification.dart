import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/entities/reconnect_result.dart';
import '../providers/connection_status_provider.dart';
import '../providers/manual_reconnect_provider.dart';

/// A persistent connection banner that shows connection status and provides reconnect controls.
/// Always visible - green when healthy, red when degraded, with Wi-Fi icon and refresh button.
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
      error: (_, stackTrace) {},
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
    final manualReconnectState = ref.watch(manualReconnectProvider);

    return connectionStatusAsync.when(
      data: (status) => _buildConnectionBanner(context, status, manualReconnectState),
      loading: () => _buildLoadingBanner(context),
      error: (error, stack) => _buildErrorBanner(context),
    );
  }

  Widget _buildConnectionBanner(
    BuildContext context,
    ConnectionStatus status,
    ManualReconnectState reconnectState,
  ) {
    final isConnected = status.allConnected;
    final backgroundColor = isConnected ? Colors.green.shade100 : Colors.red.shade100;
    final foregroundColor = isConnected ? Colors.green.shade800 : Colors.red.shade700;

    // Build list of disconnected services for messaging
    final disconnectedServices = <String>[];
    if (!status.mqttConnected) disconnectedServices.add('MQTT');
    if (!status.influxConnected) disconnectedServices.add('InfluxDB');

    final messageText = isConnected
        ? 'All services connected'
        : disconnectedServices.isEmpty
            ? 'Connection Lost'
            : '${disconnectedServices.join(', ')} disconnected';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Wi-Fi Icon with reconnect functionality
            _buildWifiIcon(context, isConnected, foregroundColor, reconnectState),
            const SizedBox(width: AppTheme.spaceSm),

            // Status message
            Expanded(
              child: _buildStatusMessage(context, messageText, foregroundColor, status, isConnected),
            ),

            // Refresh button
            _buildRefreshButton(context, foregroundColor, reconnectState),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiIcon(
    BuildContext context,
    bool isConnected,
    Color foregroundColor,
    ManualReconnectState reconnectState,
  ) {
    return GestureDetector(
      onTap: () => _handleWifiIconTap(context, reconnectState),
      onLongPress: () => _showConnectionDiagnostics(context),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceXs),
        child: Icon(
          isConnected ? Icons.wifi : Icons.wifi_off,
          color: foregroundColor,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildStatusMessage(
    BuildContext context,
    String messageText,
    Color foregroundColor,
    ConnectionStatus status,
    bool isConnected,
  ) {
    if (isConnected) {
      return Text(
        messageText,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          messageText,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (status.earliestDisconnection != null) ...[
          const SizedBox(height: 2),
          Text(
            'Disconnected ${_formatDurationForStatus(status)} ago',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor.withAlpha(180),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRefreshButton(
    BuildContext context,
    Color foregroundColor,
    ManualReconnectState reconnectState,
  ) {
    final isLoading = reconnectState.inProgress;
    final canAttempt = reconnectState.canAttempt;

    return GestureDetector(
      onTap: isLoading || !canAttempt ? null : () => _handleRefreshTap(context),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceXs),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              )
            : Icon(
                Icons.refresh,
                color: canAttempt ? foregroundColor : foregroundColor.withAlpha(120),
                size: 20,
              ),
      ),
    );
  }

  Widget _buildLoadingBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      color: Colors.grey.shade200,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.wifi, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Text(
                'Connecting...',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
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
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Text(
                'Connection Error',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleWifiIconTap(BuildContext context, ManualReconnectState reconnectState) {
    _handleRefreshTap(context);
  }

  void _handleRefreshTap(BuildContext context) async {
    if (mounted) {
      final result = await ref.read(manualReconnectProvider.notifier).attemptReconnect();
      
      if (mounted) {
        _showReconnectFeedback(context, result);
      }
    }
  }

  void _showConnectionDiagnostics(BuildContext context) {
    final connectionStatusAsync = ref.read(connectionStatusProvider);
    final manualReconnectState = ref.read(manualReconnectProvider);

    connectionStatusAsync.when(
      data: (status) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Connection Diagnostics'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDiagnosticRow('MQTT', status.mqttConnected ? 'Connected' : 'Disconnected'),
                _buildDiagnosticRow('InfluxDB', status.influxConnected ? 'Connected' : 'Disconnected'),
                if (status.earliestDisconnection != null) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  Text('Disconnected: ${_formatDurationForStatus(status)} ago'),
                ],
                if (manualReconnectState.lastResult != null) ...[
                  const SizedBox(height: AppTheme.spaceMd),
                  Text('Last reconnect: ${manualReconnectState.lastResult}'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
      loading: () {},
      error: (_, __) {},
    );
  }

  Widget _buildDiagnosticRow(String service, String status) {
    final isConnected = status == 'Connected';
    return Row(
      children: [
        Icon(
          isConnected ? Icons.check_circle : Icons.error,
          color: isConnected ? Colors.green : Colors.red,
          size: 16,
        ),
        const SizedBox(width: AppTheme.spaceXs),
        Text('$service: $status'),
      ],
    );
  }

  void _showReconnectFeedback(BuildContext context, ReconnectResult result) {
    final messenger = ScaffoldMessenger.of(context);
    
    Color backgroundColor;
    String message;
    
    if (result.allOk) {
      backgroundColor = Colors.green;
      message = 'Successfully reconnected to all services';
    } else if (result.partialSuccess) {
      backgroundColor = Colors.orange;
      message = 'Partial reconnection: ${result.mqttOk ? 'MQTT OK' : 'MQTT Failed'}, ${result.influxOk ? 'InfluxDB OK' : 'InfluxDB Failed'}';
    } else {
      backgroundColor = Colors.red;
      message = result.errorMessage ?? 'Failed to reconnect to all services';
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
