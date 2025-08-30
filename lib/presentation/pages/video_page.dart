import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../widgets/status_badge.dart';
import '../../core/theme.dart';

/// Video page for viewing live MJPEG stream from Raspberry Pi.
class VideoPage extends ConsumerWidget {
  const VideoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoStateProvider);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Feed'),
        actions: [
          StatusBadge(
            label: videoState.isConnected ? 'Connected' : 'Disconnected',
            status: videoState.isConnected ? DeviceStatus.online : DeviceStatus.offline,
          ),
          const SizedBox(width: AppTheme.spaceMd),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          children: [
            // URL input field
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Video Stream URL',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    TextFormField(
                      initialValue: videoState.streamUrl,
                      decoration: const InputDecoration(
                        hintText: 'http://192.168.1.100:8080/stream',
                        prefixIcon: Icon(Icons.link),
                      ),
                      onChanged: (url) {
                        ref.read(videoStateProvider.notifier).setStreamUrl(url);
                      },
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: videoState.isConnecting
                                ? null
                                : () {
                                    if (videoState.isConnected) {
                                      ref.read(videoStateProvider.notifier).disconnect();
                                    } else {
                                      ref.read(videoStateProvider.notifier).connect();
                                    }
                                  },
                            icon: Icon(
                              videoState.isConnected ? Icons.videocam_off : Icons.videocam,
                            ),
                            label: Text(
                              videoState.isConnecting
                                  ? 'Connecting...'
                                  : videoState.isConnected
                                      ? 'Disconnect'
                                      : 'Connect',
                            ),
                          ),
                        ),
                        if (videoState.isConnected) ...[
                          const SizedBox(width: AppTheme.spaceMd),
                          IconButton(
                            onPressed: () {
                              ref.read(videoStateProvider.notifier).refresh();
                            },
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh stream',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.spaceMd),
            
            // Video display area
            Expanded(
              child: Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: videoState.isConnected
                      ? _buildVideoFrame(context, videoState)
                      : _buildPlaceholder(context),
                ),
              ),
            ),
            
            if (videoState.isConnected) ...[
              const SizedBox(height: AppTheme.spaceMd),
              
              // Video controls
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Resolution',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            '${videoState.resolution.width}×${videoState.resolution.height}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'FPS',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            '${videoState.fps}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Latency',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            '${videoState.latency}ms',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: videoState.latency > 500
                                  ? Colors.red
                                  : videoState.latency > 200
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoFrame(BuildContext context, VideoState videoState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam,
              size: 64,
              color: Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              'Live Video Stream',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'Connected to ${videoState.streamUrl}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'No Video Stream',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Enter a stream URL and connect to view live video',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Video state model.
class VideoState {
  const VideoState({
    required this.streamUrl,
    required this.isConnected,
    required this.isConnecting,
    required this.resolution,
    required this.fps,
    required this.latency,
  });

  final String streamUrl;
  final bool isConnected;
  final bool isConnecting;
  final Size resolution;
  final int fps;
  final int latency;

  VideoState copyWith({
    String? streamUrl,
    bool? isConnected,
    bool? isConnecting,
    Size? resolution,
    int? fps,
    int? latency,
  }) {
    return VideoState(
      streamUrl: streamUrl ?? this.streamUrl,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
      latency: latency ?? this.latency,
    );
  }
}

/// Provider for video state.
final videoStateProvider = StateNotifierProvider<VideoStateNotifier, VideoState>((ref) {
  return VideoStateNotifier();
});

class VideoStateNotifier extends StateNotifier<VideoState> {
  VideoStateNotifier()
      : super(const VideoState(
          streamUrl: 'http://192.168.1.100:8080/stream',
          isConnected: false,
          isConnecting: false,
          resolution: Size(640, 480),
          fps: 30,
          latency: 150,
        ));

  void setStreamUrl(String url) {
    state = state.copyWith(streamUrl: url);
  }

  void connect() {
    state = state.copyWith(isConnecting: true);
    
    // Simulate connection process
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        state = state.copyWith(
          isConnected: true,
          isConnecting: false,
          resolution: const Size(1280, 720),
          fps: 30,
          latency: 120 + (DateTime.now().millisecond % 100),
        );
      }
    });
  }

  void disconnect() {
    state = state.copyWith(
      isConnected: false,
      isConnecting: false,
    );
  }

  void refresh() {
    // Simulate refresh
    state = state.copyWith(
      latency: 100 + (DateTime.now().millisecond % 150),
    );
  }
}