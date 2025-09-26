import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:typed_data';
import 'dart:async';

import '../../core/env.dart';
import '../../core/video/mjpeg_stream_controller.dart';
import '../providers/config_controller.dart';
import '../../domain/entities/app_config.dart';

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
    final isRealMjpeg = Env.enableRealMjpeg;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Feed'),
        actions: [
          // Simulation Mode badge when REAL_MJPEG is false
          if (!isRealMjpeg)
            Container(
              margin: const EdgeInsets.only(right: AppTheme.spaceMd),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Text(
                'Simulation Mode',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
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

  /// Build video content based on current phase
  Widget _buildVideoContent(BuildContext context, VideoState videoState) {
    switch (videoState.phase) {
      case VideoConnectionPhase.idle:
        return _buildIdleState(context);
      case VideoConnectionPhase.connecting:
        return _buildConnectingState(context);
      case VideoConnectionPhase.waitingFirstFrame:
        return _buildWaitingFirstFrameState(context);
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

  Widget _buildWaitingFirstFrameState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'Waiting for first frame...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Connected to stream, receiving data',
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
    final isRealMjpeg = Env.enableRealMjpeg;
    // Provide a stable sized container to prevent "render box has no size" before first frame.
    const fallbackAspect = 16 / 9;
    final hasFrame = isRealMjpeg && videoState.lastFrame != null;
    final aspectRatio = hasFrame
        ? (videoState.resolution.width / videoState.resolution.height)
        : fallbackAspect;

    return AspectRatio(
      aspectRatio: aspectRatio <= 0 || aspectRatio.isNaN
          ? fallbackAspect
          : aspectRatio,
      child: hasFrame
          ? _buildRealVideoFrame(context, videoState)
          : _buildPreFramePlaceholder(context, videoState, isRealMjpeg),
    );
  }

  Widget _buildPreFramePlaceholder(
    BuildContext context,
    VideoState videoState,
    bool isRealMjpeg,
  ) {
    if (!isRealMjpeg) {
      return _buildSimulationFrame(context, videoState);
    }
    // Waiting for first real frame; show progress/label within sized box.
    if (videoState.phase == VideoConnectionPhase.waitingFirstFrame ||
        videoState.phase == VideoConnectionPhase.connecting) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    // Error or idle fallback inside sized box.
    if (videoState.phase == VideoConnectionPhase.error) {
      return _buildErrorState(context, videoState);
    }
    return _buildIdleState(context); // Generic fallback
  }

  Widget _buildRealVideoFrame(BuildContext context, VideoState videoState) {
    // On web, directly embed <img> to let browser handle the multipart stream natively.
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'videoFrameHero',
            child: Image.memory(
              videoState.lastFrame!,
              gaplessPlayback: true,
              // Use contain to avoid cropping when aspect ratio mismatches during reconnect
              fit: BoxFit.contain,
            ),
          ),
          // Frame stats overlay
          Positioned(
            left: 8,
            top: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'FPS ${videoState.fps}  Frames ${videoState.framesReceived}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white),
                ),
              ),
            ),
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
    );
  }

  Widget _buildSimulationFrame(BuildContext context, VideoState videoState) {
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
                'Simulation Mode',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMd,
                  vertical: AppTheme.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'No real stream - enable REAL_MJPEG for live video',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade200,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
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
      case VideoConnectionPhase.waitingFirstFrame:
        return 'Waiting';
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
      case VideoConnectionPhase.waitingFirstFrame:
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
      case VideoConnectionPhase.waitingFirstFrame:
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
      case VideoConnectionPhase.waitingFirstFrame:
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
      case VideoConnectionPhase.waitingFirstFrame:
        return 'Waiting...';
      case VideoConnectionPhase.playing:
        return 'Disconnect';
      case VideoConnectionPhase.error:
        return 'Retry';
    }
  }
}

/// Connection phases for MJPEG streaming
enum VideoConnectionPhase {
  idle,
  connecting,
  waitingFirstFrame,
  playing,
  error,
}

/// Video state model with phase-based connection states
class VideoState {
  const VideoState({
    required this.streamUrl,
    required this.phase,
    required this.hasAttempted,
    required this.resolution,
    required this.fps,
    required this.latency,
    this.lastFrame,
    this.framesReceived = 0,
    this.errorMessage,
  });

  final String streamUrl;
  final VideoConnectionPhase phase;
  final bool hasAttempted;
  final Size resolution;
  final int fps;
  final int latency;
  final Uint8List? lastFrame;
  final int framesReceived;
  final String? errorMessage;

  // Derived getters for backward compatibility
  bool get isConnected => phase == VideoConnectionPhase.playing;
  bool get isConnecting => phase == VideoConnectionPhase.connecting;
  bool get isWaitingFirstFrame =>
      phase == VideoConnectionPhase.waitingFirstFrame;
  bool get isIdle => phase == VideoConnectionPhase.idle;
  bool get isError => phase == VideoConnectionPhase.error;

  VideoState copyWith({
    String? streamUrl,
    VideoConnectionPhase? phase,
    bool? hasAttempted,
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
      phase: phase ?? this.phase,
      hasAttempted: hasAttempted ?? this.hasAttempted,
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
      // Watch config and pass it to the notifier
      final configAsync = ref.watch(configControllerProvider);
      final videoConfig = configAsync.whenData((config) => config.video).value ?? VideoConfig.fromEnv();
      
      return VideoStateNotifier(ref, videoConfig);
    });

class VideoStateNotifier extends StateNotifier<VideoState> {
  VideoStateNotifier(this._ref, VideoConfig videoConfig)
    : super(VideoState(
        streamUrl: videoConfig.mjpegUrl,
        phase: VideoConnectionPhase.idle,
        hasAttempted: false,
        resolution: const Size(640, 480),
        fps: 30,
        latency: 150,
      ));

  final Ref _ref;
  StreamSubscription<FrameEvent>? _eventSub;
  Timer? _connectTimeoutTimer; // Enforces max wait before first frame

  void setStreamUrl(String url) {
    state = state.copyWith(streamUrl: url);
    // Update video config in the controller when URL changes
    final configController = _ref.read(configControllerProvider.notifier);
    configController.updateVideoConfig(VideoConfig(mjpegUrl: url, autoReconnect: true));
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

    if (!Env.enableRealMjpeg) {
      // Simulation mode - follow same phase semantics
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          // Skip waitingFirstFrame and go straight to playing in simulation
          _cancelConnectTimeout();
          state = state.copyWith(
            phase: VideoConnectionPhase.playing,
            resolution: const Size(1280, 720),
            fps: 30,
            latency: 120 + (DateTime.now().millisecond % 100),
          );
        }
      });
      // Still start timeout in case simulation future never fires for some reason
      _startConnectTimeout();
      return;
    }

    // Real MJPEG streaming
    final controller = _ref.read(mjpegStreamControllerProvider);
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
      lastFrame: null,
      framesReceived: 0,
    );
    if (Env.enableRealMjpeg) {
      _eventSub?.cancel();
      _eventSub = null;
      _ref.read(mjpegStreamControllerProvider).stop();
    }
  }

  /// Silent shutdown used by widget dispose to avoid scheduling rebuilds
  /// while element tree is tearing down. Does not mutate state; only
  /// releases resources.
  void shutdown() {
    if (Env.enableRealMjpeg) {
      _eventSub?.cancel();
      _eventSub = null;
      _ref.read(mjpegStreamControllerProvider).stop();
    }
    _cancelConnectTimeout();
  }

  void refresh() {
    // Only refresh when actually playing
    if (state.phase == VideoConnectionPhase.playing) {
      state = state.copyWith(latency: 100 + (DateTime.now().millisecond % 150));
    }
  }

  void _onEvent(FrameEvent event) {
    if (event is StreamStarted) {
      state = state.copyWith(phase: VideoConnectionPhase.waitingFirstFrame);
    } else if (event is FrameResolution) {
      // Update resolution metadata without marking playing yet (first FrameBytes will)
      final w = event.width.toDouble();
      final h = event.height.toDouble();
      if (w > 0 && h > 0) {
        state = state.copyWith(resolution: Size(w, h));
      }
    } else if (event is FrameBytes) {
      // First frame transitions to playing
      _cancelConnectTimeout();
      state = state.copyWith(
        phase: VideoConnectionPhase.playing,
        lastFrame: event.bytes,
        framesReceived: state.framesReceived + 1,
        fps: state.fps,
        latency: 100 + (DateTime.now().millisecond % 150),
      );
    } else if (event is StreamError) {
      _cancelConnectTimeout();
      state = state.copyWith(
        phase: VideoConnectionPhase.error,
        errorMessage: event.error.toString(),
      );
    } else if (event is StreamEnded) {
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
    _connectTimeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (state.phase == VideoConnectionPhase.connecting ||
          state.phase == VideoConnectionPhase.waitingFirstFrame) {
        // Treat as connection failure.
        _eventSub?.cancel();
        _eventSub = null;
        if (Env.enableRealMjpeg) {
          _ref.read(mjpegStreamControllerProvider).stop();
        }
        state = state.copyWith(
          phase: VideoConnectionPhase.error,
          errorMessage: 'Connection timeout after 5s',
        );
      }
    });
  }

  void _cancelConnectTimeout() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = null;
  }
}

// --- JPEG Utilities -------------------------------------------------------
// Parses JPEG markers to find SOF0/SOF2 and return dimensions.
// JPEG dimension parsing no longer needed on client; resolution now comes via FrameResolution event.

/// Fullscreen video page using same providers; shows last frame stretching to fit.
class _FullscreenVideoPage extends ConsumerWidget {
  const _FullscreenVideoPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoStateProvider);
    final isRealMjpeg = Env.enableRealMjpeg;

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
                    child: _buildFullscreenContent(
                      context,
                      videoState,
                      isRealMjpeg,
                    ),
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
            // Only show stats when playing
            if (videoState.phase == VideoConnectionPhase.playing)
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
                    _StatChip(
                      label: 'Latency',
                      value: '${videoState.latency}ms',
                    ),
                  ],
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
    bool isRealMjpeg,
  ) {
    switch (videoState.phase) {
      case VideoConnectionPhase.playing:
        if (isRealMjpeg && videoState.lastFrame != null) {
          return Image.memory(
            videoState.lastFrame!,
            gaplessPlayback: true,
            fit: BoxFit.contain,
          );
        } else {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Simulation Mode',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
              ],
            ),
          );
        }
      case VideoConnectionPhase.waitingFirstFrame:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Waiting for first frame...',
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
