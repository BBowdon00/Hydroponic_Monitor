import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:typed_data';
import 'dart:async';

import '../../core/env.dart';
import '../../core/video/mjpeg_stream_controller.dart';

import '../widgets/status_badge.dart';
import '../../core/theme.dart';
import '../../domain/entities/device.dart';

/// Video page for viewing live MJPEG stream from Raspberry Pi.
// Controller provider keeps TextEditingController lifecycle tied to ProviderScope.
final _urlTextControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();

  // Seed with current state value.
  controller.text = ref.read(videoStateProvider).streamUrl;

  // Propagate user edits.
  void listener() {
    ref.read(videoStateProvider.notifier).setStreamUrl(controller.text);
  }

  controller.addListener(listener);

  // Listen to state changes to stay in sync if updated elsewhere.
  ref.listen(videoStateProvider, (prev, next) {
    if (controller.text != next.streamUrl) {
      controller.text = next.streamUrl;
    }
  });

  ref.onDispose(() {
    controller.removeListener(listener);
    controller.dispose();
  });

  return controller;
});

class VideoPage extends ConsumerWidget {
  const VideoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoStateProvider);
    final urlController = ref.watch(_urlTextControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Feed'),
        actions: [
          StatusBadge(
            label: videoState.isConnected ? 'Connected' : 'Disconnected',
            status: videoState.isConnected
                ? DeviceStatus.online
                : DeviceStatus.offline,
          ),
          const SizedBox(width: AppTheme.spaceMd),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool enableScroll = constraints.maxHeight < 600;

            Widget buildVideoArea() {
              final card = Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: videoState.isConnected
                      ? _buildVideoFrame(context, videoState)
                      : _buildPlaceholder(context),
                ),
              );
              if (enableScroll) {
                // In scroll mode we cannot use Expanded/Flexible (unbounded height)
                return card;
              }
              return Expanded(child: card);
            }

            final children = <Widget>[
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
                        controller: urlController,
                        decoration: const InputDecoration(
                          hintText: 'http://192.168.1.100:8080/stream',
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              key: const Key('video_connect_button'),
                              onPressed: videoState.isConnecting
                                  ? null
                                  : () {
                                      if (videoState.isConnected) {
                                        ref
                                            .read(videoStateProvider.notifier)
                                            .disconnect();
                                      } else {
                                        ref
                                            .read(videoStateProvider.notifier)
                                            .connect();
                                      }
                                    },
                              icon: Icon(
                                videoState.isConnected
                                    ? Icons.videocam_off
                                    : Icons.videocam,
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
              buildVideoArea(),
              if (videoState.isConnected) ...[
                const SizedBox(height: AppTheme.spaceMd),
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
                              '${videoState.resolution.width.toInt()}×${videoState.resolution.height.toInt()}',
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text('FPS', style: theme.textTheme.bodySmall),
                            Text(
                              '${videoState.fps}',
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text('Latency', style: theme.textTheme.bodySmall),
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
            ];

            final column = Column(
              mainAxisSize: enableScroll ? MainAxisSize.min : MainAxisSize.max,
              children: children,
            );
            if (enableScroll) {
              return SingleChildScrollView(child: column);
            }
            return column;
          },
        ),
      ),
    );
  }

  Widget _buildVideoFrame(BuildContext context, VideoState videoState) {
    final isReal = Env.enableRealMjpeg;
    final waitingForFirstFrame =
        isReal && videoState.isConnected && videoState.lastFrame == null;

    if (isReal) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoState.lastFrame != null)
              Hero(
                tag: 'videoFrameHero',
                child: Image.memory(
                  videoState.lastFrame!,
                  gaplessPlayback: true,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator()),
              ),
            if (waitingForFirstFrame)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 72),
                  child: Text(
                    'Waiting for first frame...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            Positioned(
              left: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'FPS ${videoState.fps}  Frames ${videoState.framesReceived}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                key: const Key('fullscreen_button'),
                icon: const Icon(Icons.fullscreen, color: Colors.white70),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _FullscreenVideoPage(),
                    ),
                  );
                },
              ),
            ),
            if (videoState.errorMessage != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  color: Colors.red.withValues(alpha: 0.7),
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    videoState.errorMessage!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Simulated placeholder (also supports fullscreen navigation for consistency)
    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const _FullscreenVideoPage()));
      },
      child: Container(
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
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                'Live Video Stream',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                'Connected to ${videoState.streamUrl}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
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
    this.lastFrame,
    this.framesReceived = 0,
    this.errorMessage,
  });

  final String streamUrl;
  final bool isConnected;
  final bool isConnecting;
  final Size resolution;
  final int fps;
  final int latency;
  final Uint8List? lastFrame;
  final int framesReceived;
  final String? errorMessage;

  VideoState copyWith({
    String? streamUrl,
    bool? isConnected,
    bool? isConnecting,
    Size? resolution,
    int? fps,
    int? latency,
    Uint8List? lastFrame,
    int? framesReceived,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VideoState(
      streamUrl: streamUrl ?? this.streamUrl,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
      latency: latency ?? this.latency,
      lastFrame: lastFrame ?? this.lastFrame,
      framesReceived: framesReceived ?? this.framesReceived,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Provider for video state.
final mjpegStreamControllerProvider = Provider<MjpegStreamController>((ref) {
  return MjpegStreamController();
});

final videoStateProvider =
    StateNotifierProvider<VideoStateNotifier, VideoState>((ref) {
      return VideoStateNotifier(ref);
    });

class VideoStateNotifier extends StateNotifier<VideoState> {
  VideoStateNotifier(this._ref)
    : super(
        const VideoState(
          streamUrl: 'http://192.168.1.100:8080/stream',
          isConnected: false,
          isConnecting: false,
          resolution: Size(640, 480),
          fps: 30,
          latency: 150,
        ),
      );

  final Ref _ref;
  StreamSubscription<FrameEvent>? _eventSub;

  void setStreamUrl(String url) {
    state = state.copyWith(streamUrl: url);
  }

  void connect() {
    if (state.isConnecting || state.isConnected) return;
    state = state.copyWith(isConnecting: true, clearError: true);
    if (!Env.enableRealMjpeg) {
      // Simulated path
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
      return;
    }

    final controller = _ref.read(mjpegStreamControllerProvider);
    _eventSub = controller.events.listen(_onEvent);
    controller.start(Uri.parse(state.streamUrl));
  }

  void disconnect() {
    state = state.copyWith(isConnected: false, isConnecting: false);
    if (Env.enableRealMjpeg) {
      _eventSub?.cancel();
      _ref.read(mjpegStreamControllerProvider).stop();
    }
  }

  void refresh() {
    // Simulate refresh
    state = state.copyWith(latency: 100 + (DateTime.now().millisecond % 150));
  }

  void _onEvent(FrameEvent event) {
    if (event is StreamStarted) {
      state = state.copyWith(isConnected: true, isConnecting: false);
    } else if (event is FrameBytes) {
      // Estimate fps naive: increment count and use fixed 30 for now
      state = state.copyWith(
        lastFrame: event.bytes,
        framesReceived: state.framesReceived + 1,
        fps: state.fps,
        latency: 100 + (DateTime.now().millisecond % 150),
      );
    } else if (event is StreamError) {
      state = state.copyWith(
        errorMessage: event.error.toString(),
        isConnecting: false,
      );
    } else if (event is StreamEnded) {
      state = state.copyWith(isConnected: false, isConnecting: false);
    }
  }
}

/// Fullscreen video page using same providers; shows last frame stretching to fit.
class _FullscreenVideoPage extends ConsumerWidget {
  const _FullscreenVideoPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoStateProvider);
    final isReal = Env.enableRealMjpeg;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: 'videoFrameHero',
                child: AspectRatio(
                  aspectRatio:
                      videoState.resolution.width /
                      videoState.resolution.height,
                  child: Container(
                    color: Colors.black,
                    child: isReal && videoState.lastFrame != null
                        ? Image.memory(
                            videoState.lastFrame!,
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Exit Fullscreen',
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatChip(label: 'FPS', value: '${videoState.fps}'),
                  _StatChip(
                    label: 'Frames',
                    value: '${videoState.framesReceived}',
                  ),
                  _StatChip(label: 'Latency', value: '${videoState.latency}ms'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.white70),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
