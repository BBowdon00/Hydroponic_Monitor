import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';

import '../../core/env.dart';
import '../providers/config_provider.dart';
import '../../domain/entities/app_config.dart';
import '../../core/video/hls_stream_controller.dart';

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

/// VideoPage now a Stateful widget so we can perform a safe disconnect in dispose
/// without triggering provider reads during ProviderContainer teardown (which was
/// causing Bad state: Tried to read a provider from a ProviderContainer that was already disposed).
class VideoPage extends ConsumerStatefulWidget {
  const VideoPage({super.key});

  @override
  ConsumerState<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends ConsumerState<VideoPage> {
  late final VideoStateNotifier _videoNotifier;

  @override
  void initState() {
    super.initState();
    // Capture notifier early so dispose doesn't attempt a provider read after container teardown.
    _videoNotifier = ref.read(videoStateProvider.notifier);
  }

  @override
  void dispose() {
    // Perform a silent shutdown to release resources without emitting state changes
    // that would try to rebuild this (now disposing) widget.
    _videoNotifier.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoStateProvider);
    final urlController = ref.watch(_urlTextControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Feed'),
        actions: [
          StatusBadge(
            label: _getStatusLabel(videoState.phase),
            status: _getDeviceStatus(videoState.phase),
          ),
          const SizedBox(width: AppTheme.spaceMd),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // FIX: Previously used constraints.maxHeight (<600) which shrank when the
            // keyboard appeared, toggling between scroll/non-scroll layouts and
            // rebuilding the TextFormField -> focus lost & keyboard dismissed.
            // Use the full screen height (independent of keyboard insets) so the
            // structural layout stays stable while typing.
            final screenHeight = MediaQuery.of(context).size.height;
            final bool enableScroll = screenHeight < 600;

            Widget buildVideoArea() {
              final card = Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: _buildVideoContent(context, videoState),
                ),
              );
              if (enableScroll) {
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
                        'HLS Stream URL',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppTheme.spaceSm),
                      TextFormField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          hintText: 'http://192.168.1.100:8080/hls/stream.m3u8',
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              key: const Key('video_connect_button'),
                              onPressed: _getConnectButtonAction(
                                videoState,
                                ref,
                              ),
                              icon: _getConnectButtonIcon(videoState.phase),
                              label: Text(
                                _getConnectButtonLabel(videoState.phase),
                              ),
                            ),
                          ),
                          // Refresh button only when playing
                          if (videoState.phase ==
                              VideoConnectionPhase.playing) ...[
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
              if (videoState.phase == VideoConnectionPhase.playing) ...[
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
                            Text('Status', style: theme.textTheme.bodySmall),
                            Text(
                              'Playing',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.green,
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

  /// Build video content based on current phase
  Widget _buildVideoContent(BuildContext context, VideoState videoState) {
    switch (videoState.phase) {
      case VideoConnectionPhase.idle:
        return _buildIdleState(context);
      case VideoConnectionPhase.connecting:
        return _buildConnectingState(context);
      case VideoConnectionPhase.buffering:
        return _buildBufferingState(context);
      case VideoConnectionPhase.playing:
        return _buildPlayingState(context, videoState);
      case VideoConnectionPhase.error:
        return _buildErrorState(context, videoState);
    }
  }

  Widget _buildIdleState(BuildContext context) {
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
            'No stream connected',
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

  Widget _buildConnectingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTheme.spaceMd),
          Text('Connecting...', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _buildBufferingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'Buffering...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Loading video stream',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayingState(BuildContext context, VideoState videoState) {
    // Get the video player controller from HLS stream controller
    final hlsController = ref.read(hlsStreamControllerProvider);
    final videoController = hlsController.controller;
    
    if (videoController == null || !videoController.value.isInitialized) {
      return _buildBufferingState(context);
    }

    final aspectRatio = videoController.value.aspectRatio > 0
        ? videoController.value.aspectRatio
        : 16 / 9;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'videoFrameHero',
              child: VideoPlayer(videoController),
            ),
            // Fullscreen button (only when playing)
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
            // Error overlay
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
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, VideoState videoState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'Connection Error',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          if (videoState.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                videoState.errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // Helper methods for phase-based UI
  String _getStatusLabel(VideoConnectionPhase phase) {
    switch (phase) {
      case VideoConnectionPhase.idle:
        return 'Disconnected';
      case VideoConnectionPhase.connecting:
        return 'Connecting';
      case VideoConnectionPhase.buffering:
        return 'Buffering';
      case VideoConnectionPhase.playing:
        return 'Playing';
      case VideoConnectionPhase.error:
        return 'Error';
    }
  }

  DeviceStatus _getDeviceStatus(VideoConnectionPhase phase) {
    switch (phase) {
      case VideoConnectionPhase.idle:
        return DeviceStatus.offline;
      case VideoConnectionPhase.connecting:
      case VideoConnectionPhase.buffering:
        return DeviceStatus.unknown;
      case VideoConnectionPhase.playing:
        return DeviceStatus.online;
      case VideoConnectionPhase.error:
        return DeviceStatus.error;
    }
  }

  VoidCallback? _getConnectButtonAction(VideoState videoState, WidgetRef ref) {
    switch (videoState.phase) {
      case VideoConnectionPhase.connecting:
      case VideoConnectionPhase.buffering:
        return null; // Disabled during connection process
      case VideoConnectionPhase.idle:
      case VideoConnectionPhase.error:
        return () => ref.read(videoStateProvider.notifier).connect();
      case VideoConnectionPhase.playing:
        return () => ref.read(videoStateProvider.notifier).disconnect();
    }
  }

  Widget _getConnectButtonIcon(VideoConnectionPhase phase) {
    switch (phase) {
      case VideoConnectionPhase.connecting:
      case VideoConnectionPhase.buffering:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case VideoConnectionPhase.idle:
      case VideoConnectionPhase.error:
        return const Icon(Icons.play_arrow);
      case VideoConnectionPhase.playing:
        return const Icon(Icons.stop);
    }
  }

  String _getConnectButtonLabel(VideoConnectionPhase phase) {
    switch (phase) {
      case VideoConnectionPhase.idle:
        return 'Connect';
      case VideoConnectionPhase.connecting:
        return 'Connecting...';
      case VideoConnectionPhase.buffering:
        return 'Buffering...';
      case VideoConnectionPhase.playing:
        return 'Disconnect';
      case VideoConnectionPhase.error:
        return 'Retry';
    }
  }
}

/// Connection phases for HLS streaming
enum VideoConnectionPhase {
  idle,
  connecting,
  buffering,
  playing,
  error,
}

/// Video state model with phase-based connection states for HLS
class VideoState {
  const VideoState({
    required this.streamUrl,
    required this.phase,
    required this.hasAttempted,
    required this.resolution,
    this.errorMessage,
  });

  final String streamUrl;
  final VideoConnectionPhase phase;
  final bool hasAttempted;
  final Size resolution;
  final String? errorMessage;

  // Derived getters for backward compatibility
  bool get isConnected => phase == VideoConnectionPhase.playing;
  bool get isConnecting => phase == VideoConnectionPhase.connecting;
  bool get isBuffering => phase == VideoConnectionPhase.buffering;
  bool get isIdle => phase == VideoConnectionPhase.idle;
  bool get isError => phase == VideoConnectionPhase.error;

  VideoState copyWith({
    String? streamUrl,
    VideoConnectionPhase? phase,
    bool? hasAttempted,
    Size? resolution,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VideoState(
      streamUrl: streamUrl ?? this.streamUrl,
      phase: phase ?? this.phase,
      hasAttempted: hasAttempted ?? this.hasAttempted,
      resolution: resolution ?? this.resolution,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Provider for HLS stream controller
final hlsStreamControllerProvider = Provider<HlsStreamController>((ref) {
  final controller = HlsStreamController();
  ref.onDispose(() => controller.dispose());
  return controller;
});

final videoStateProvider = StateNotifierProvider<VideoStateNotifier, VideoState>(
  (ref) {
    // Use ref.read instead of watch so the notifier instance is stable and not
    // torn down when configProvider transitions from loading->data (which was
    // causing disposed notifier access in tests and potential UI flicker).
    final config = ref.read(configProvider).valueOrNull;
    final initialUrl = config?.hls.url.isNotEmpty == true
        ? config!.hls.url
        : (Env.hlsUrl.isNotEmpty
              ? Env.hlsUrl
              : 'http://192.168.1.100:8080/hls/stream.m3u8');
    return VideoStateNotifier(ref, initialUrl: initialUrl);
  },
);

class VideoStateNotifier extends StateNotifier<VideoState> {
  VideoStateNotifier(this._ref, {required String initialUrl})
    : super(
        VideoState(
          streamUrl: initialUrl,
          phase: VideoConnectionPhase.idle,
          hasAttempted: false,
          resolution: const Size(640, 480),
        ),
      ) {
    // Listen for config changes; if HLS URL changes and we're idle (not connected), update field.
    _configSub = _ref.listen<AsyncValue<AppConfig>>(configProvider, (
      prev,
      next,
    ) {
      final newUrl = next.valueOrNull?.hls.url;
      if (newUrl != null && newUrl.isNotEmpty) {
        // Only adopt config URL automatically if user hasn't manually set one yet
        // and we're idle. This prevents clobbering a URL the user typed before
        // config finished loading (observed in integration tests).
        if (!_userModified && state.isIdle && state.streamUrl != newUrl) {
          state = state.copyWith(streamUrl: newUrl);
        }
      }
    });
  }

  final Ref _ref;
  StreamSubscription<HlsEvent>? _eventSub;
  ProviderSubscription<AsyncValue<AppConfig>>? _configSub;
  Timer? _connectTimeoutTimer; // Enforces max wait before first frame
  bool _userModified = false; // Tracks whether user explicitly set URL

  void setStreamUrl(String url) {
    _userModified = true;
    state = state.copyWith(streamUrl: url);
  }

  void connect() {
    if (state.phase == VideoConnectionPhase.connecting ||
        state.phase == VideoConnectionPhase.playing)
      return;

    _cancelConnectTimeout();
    state = state.copyWith(
      phase: VideoConnectionPhase.connecting,
      hasAttempted: true,
      clearError: true,
    );

    // Real HLS streaming
    final controller = _ref.read(hlsStreamControllerProvider);
    _eventSub = controller.events.listen(_onEvent);
    controller.start(state.streamUrl);
    _startConnectTimeout();
  }

  void disconnect() {
    // Reset phase and revert resolution so AspectRatio fallback is consistent on next connect
    _cancelConnectTimeout();
    state = state.copyWith(
      phase: VideoConnectionPhase.idle,
      resolution: const Size(640, 480),
    );
    _eventSub?.cancel();
    _eventSub = null;
    _ref.read(hlsStreamControllerProvider).stop();
  }

  /// Silent shutdown used by widget dispose to avoid scheduling rebuilds
  /// while element tree is tearing down. Does not mutate state; only
  /// releases resources.
  void shutdown() {
    _eventSub?.cancel();
    _eventSub = null;
    _ref.read(hlsStreamControllerProvider).stop();
    _cancelConnectTimeout();
    _configSub?.close();
  }

  void refresh() {
    // Refresh by reconnecting to stream
    if (state.phase == VideoConnectionPhase.playing) {
      disconnect();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) connect();
      });
    }
  }

  void _onEvent(HlsEvent event) {
    if (event is HlsStreamStarted) {
      _cancelConnectTimeout();
      final w = event.width;
      final h = event.height;
      state = state.copyWith(
        phase: VideoConnectionPhase.playing,
        resolution: (w > 0 && h > 0) ? Size(w, h) : state.resolution,
      );
    } else if (event is HlsStreamBuffering) {
      state = state.copyWith(phase: VideoConnectionPhase.buffering);
    } else if (event is HlsStreamPlaying) {
      state = state.copyWith(phase: VideoConnectionPhase.playing);
    } else if (event is HlsStreamError) {
      _cancelConnectTimeout();
      state = state.copyWith(
        phase: VideoConnectionPhase.error,
        errorMessage: event.error.toString(),
      );
    } else if (event is HlsStreamEnded) {
      _cancelConnectTimeout();
      // Stream ended - go to idle unless it was an error
      state = state.copyWith(
        phase: state.errorMessage != null
            ? VideoConnectionPhase.error
            : VideoConnectionPhase.idle,
      );
    }
  }

  // --- Timeout Helpers --------------------------------------------------
  void _startConnectTimeout() {
    _connectTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (state.phase == VideoConnectionPhase.connecting ||
          state.phase == VideoConnectionPhase.buffering) {
        // Treat as connection failure.
        _eventSub?.cancel();
        _eventSub = null;
        _ref.read(hlsStreamControllerProvider).stop();
        state = state.copyWith(
          phase: VideoConnectionPhase.error,
          errorMessage: 'Connection timeout after 10s',
        );
      }
    });
  }

  void _cancelConnectTimeout() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
  }
}

/// Fullscreen video page for HLS video playback
class _FullscreenVideoPage extends ConsumerWidget {
  const _FullscreenVideoPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoStateProvider);
    final hlsController = ref.read(hlsStreamControllerProvider);
    final videoController = hlsController.controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: 'videoFrameHero',
                child: videoController != null && videoController.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: videoController.value.aspectRatio > 0
                            ? videoController.value.aspectRatio
                            : 16 / 9,
                        child: VideoPlayer(videoController),
                      )
                    : AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: Colors.black,
                          child: _buildFullscreenContent(context, videoState),
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
            // Show status label
            if (videoState.phase != VideoConnectionPhase.playing)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Center(
                  child: _StatChip(
                    label: 'Status',
                    value: videoState.phase.name,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenContent(
    BuildContext context,
    VideoState videoState,
  ) {
    switch (videoState.phase) {
      case VideoConnectionPhase.buffering:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Buffering...',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),
        );
      case VideoConnectionPhase.connecting:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Connecting...',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),
        );
      case VideoConnectionPhase.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Connection Error',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.red.shade300),
              ),
            ],
          ),
        );
      case VideoConnectionPhase.idle:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off,
                size: 80,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                'No stream connected',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.white),
              ),
            ],
          ),
        );
      case VideoConnectionPhase.playing:
        // Should not reach here as we check for initialized controller
        return const SizedBox.shrink();
    }
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
