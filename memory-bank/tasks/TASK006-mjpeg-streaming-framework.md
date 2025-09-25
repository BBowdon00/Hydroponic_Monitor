# TASK006: MJPEG Streaming Framework & Testing

## Status: IN PROGRESS (Reopened)

Priority: Medium
Created: 2025-09-25
Owner: GitHub Copilot

## Context
A video (MJPEG) streaming interface was scaffolded with simulated connection logic (placeholder UI, timing-based state transitions). This task previously documented only the *test framework* and marked itself complete. It has been REOPENED to implement the real network-capable MJPEG streaming pipeline (HTTP acquisition, multipart parsing, frame decoding, resilience, performance) required for a production-ready camera feed.

## Problem Statement
Users need to view a live MJPEG camera feed. Current code only simulates connection state (delayed success + synthetic latency) and does *not* open or parse a multipart/x-mixed-replace HTTP stream. Without an actual network layer, the feature is non-functional with a real camera.

## Goals & Acceptance Criteria

| Goal | Status | Notes |
|------|--------|-------|
| Simulated UI states (disconnected/connecting/connected) | Done | Basic state machine via `VideoStateNotifier` |
| Placeholder rendering & controls | Done | URL input, connect/disconnect, refresh latency |
| Unit tests for state model & transitions | Done | `test/unit/video_state_test.dart` |
| Integration tests for lifecycle & multi-container isolation | Done | `test/integration/video_streaming_test.dart` |
| Widget tests for video page UI | Done | `test/presentation/pages/video_page_test.dart` |
| Comprehensive testing guide | Done | `docs/testing/mjpeg-streaming-testing-guide.md` |
| Real MJPEG HTTP stream connection | Done (Feature-flagged) | Implemented via `MjpegStreamController` behind `REAL_MJPEG` flag |
| Multipart boundary parsing & JPEG frame extraction | Done (Basic) | Incremental boundary scanner emits `FrameBytes` events |
| Frame rendering (Image.memory or optimized pipeline) | Done (Basic) | Renders last frame with stats overlay |
| Error & reconnect logic (timeouts, retries, invalid content-type) | Partial | Invalid content-type / boundary errors surfaced; retries deferred |
| Performance throttling (FPS limiting / skip frames) | Not Started | Configurable target FPS cap |
| Metrics & instrumentation (fps, errors) | Not Started | For observability & tuning |
| Graceful shutdown & resource cleanup | Not Started | Cancel HTTP request & close sockets |
| Fake MJPEG test server (fixture) | Not Started | For deterministic integration tests |

## Non-Goals (Current Phase)
- Implementing websocket/HLS/RTSP fallback
- Persisting last successful frame to disk
- Authentication headers / token rotation
- Multi-camera switching UI

## Implementation Summary (What Exists Now)
- `VideoState` + `VideoStateNotifier`: simulation only (no network IO)
- `VideoPage`: displays placeholder or simulated "live" frame container (no actual MJPEG decoding)
- Tests cover state transitions, URL mutation, simulated connection, latency variability, basic UX flows
- Documentation outlines manual + automated test procedures

## Gaps / Required Work for Real Streaming
1. **HTTP Stream Acquisition**
   - Use `HttpClient` (mobile/desktop) or platform-appropriate client for web (CORS constraints) to GET the stream
   - Validate `Content-Type` header: must include `multipart/x-mixed-replace; boundary=...`
2. **Multipart Boundary Parser**
   - Incremental line / chunk reader
   - Detect `--<boundary>` markers
   - Parse part headers until blank line
   - Accumulate JPEG bytes until next boundary
3. **Frame Decoding & Delivery**
   - Emit bytes through `Stream<Uint8List>` or Riverpod provider
   - Render with `Image.memory(frameBytes)` or custom painter
4. **State Management Enhancements**
   - Add states: buffering, error, reconnecting
   - Track last frame timestamp, fps calculation window
5. **Error Handling & Resilience**
   - Timeouts: no first frame within N seconds → fail
   - Retry with exponential backoff
   - Graceful disconnect on user request
6. **Performance Considerations**
   - Cap frame updates to avoid rebuild storms
   - Optionally decode off main isolate (compute / isolate)
7. **Testing Additions**
   - Fake MJPEG server for integration tests (serve scripted multipart payload)
   - Corrupted frame & boundary anomaly tests
   - Network interruption simulation

## Implementation Plan (Phased)

### Phase 0: Foundations (Current State Alignment)
- Confirm existing simulated `VideoStateNotifier` usage points in UI.
- Introduce feature flag: `enableRealMjpeg` (default false until stable) to allow incremental integration without breaking tests.

### Phase 1: Streaming Service Skeleton
- Create `lib/core/video/mjpeg_stream_controller.dart` with interface:
   - `Future<void> start(Uri url, {Map<String,String>? headers})`
   - `Stream<FrameEvent> get frames`
   - `Future<void> stop()`
- Define `FrameEvent` sealed class:
   - `FrameBytes(Uint8List bytes, int index, DateTime ts)`
   - `StreamStarted(boundary, DateTime ts)`
   - `StreamError(error, stack, DateTime ts)`
   - `StreamEnded(DateTime ts, {String? reason})`
- Use `HttpClient` (mobile/desktop) & conditional import for web (`browser_client`).
- Validate `Content-Type` header pattern: `multipart/x-mixed-replace; boundary=...`.

### Phase 2: Incremental Multipart Parser (Implemented)
- Implement incremental line buffer & boundary detection (case-sensitive match on prefixed `--`).
- Parse part headers until blank line; extract `Content-Length` (optional) & `Content-Type` (expect `image/jpeg`).
- Accumulate bytes until next boundary or `Content-Length` satisfied.
- Emit `FrameBytes` events.
- Abort with `StreamError` on malformed boundary or oversized frame (> configurable max, e.g. 2 MB).

### Phase 3: Riverpod Integration (Implemented)
- Add `mjpegStreamControllerProvider` (provider of singleton / factory) & `mjpegFrameStreamProvider` (StreamProvider<FrameEvent>).
- Refactor `VideoStateNotifier` → orchestrator that:
   - Initiates start/stop via controller.
   - Transitions states: `connecting`, `buffering` (before first frame), `playing`, `error`, `stopped`, `reconnecting`.
- Maintain counters: `framesReceived`, `droppedFrames`, `avgFps` (sliding window 2–5 s).

### Phase 4: UI Update (Implemented)
- Replace placeholder container with:
   - `Image.memory(lastFrameBytes, gaplessPlayback: true)`.
   - Fallback progress indicator while buffering.
   - Error banner with retry action.
   - Overlay stats (FPS, resolution if derivable) behind debug flag.

### Phase 5: Resilience & Retry
- Add configurable options object (`MjpegStreamConfig`): timeouts (connect, firstFrame), retry policy (max attempts, backoff base), maxFrameBytes, fpsCap.
- Implement exponential backoff with jitter for reconnect (e.g. 0.5x–1.5x randomized).
- Detect stalls: no frame for N seconds → attempt soft reconnect.
- Distinguish recoverable vs fatal errors (HTTP 401/403 vs transient network).

### Phase 6: Performance Optimizations
- Optional isolate for parsing: move boundary scan + header parse into isolate when frame rate > target or parse time spikes.
- Frame rate limiting: if incoming frames exceed target FPS, drop older frames (keep latest) without queue growth.
- Memory hygiene: reuse `Uint8List` buffers via pool to reduce GC churn (defer unless profiling shows pressure).

### Phase 7: Comprehensive Testing
1. Unit Tests
    - Parser: boundary splits across chunks, missing CRLF, corrupted headers, oversize frame, truncated stream.
    - Retry policy logic (deterministic with injected clock & RNG).
2. Integration Tests (Fake Server)
    - Normal stream 5 frames.
    - Boundary anomaly (duplicate boundary) triggers error.
    - Slow first frame triggers timeout → error state.
    - Mid-stream disconnect → reconnect path produces continued frames.
3. Widget Tests
    - UI reflects buffering → playing transitions with fake frame provider.
    - Error overlay appears on injected error.
4. Performance (Optional Bench Harness)
    - Micro-benchmark parser throughput (frames/sec for synthetic payload).

### Phase 8: Observability & Telemetry
- Add lightweight logging (debug level) with category `video.mjpeg`.
- Expose metrics provider: `{fps, framesReceived, dropped, avgLatencyMs, lastError}`.
- Optional integration with existing app diagnostics panel (if present) or create a simple debug drawer section.

### Phase 9: Hardening & Polishing
- Graceful stop ensures HTTP request aborted & isolate terminated.
- Cancel pending timers on dispose.
- Defensive error messages for user-friendly display vs internal detail.
- Security: sanitize logged URLs (remove credentials/query secrets).
- Document configuration & troubleshooting in README section.

## Data Structures & Contracts
- `FrameEvent` (sealed / union) ensures exhaustive handling.
- `MjpegStreamConfig`:
   - `Duration connectTimeout`
   - `Duration firstFrameTimeout`
   - `Duration stallTimeout`
   - `int maxFrameBytes`
   - `int? targetFps`
   - `RetryPolicy retryPolicy`
- `RetryPolicy`:
   - `int maxAttempts`
   - `Duration baseDelay`
   - `double backoffFactor`
   - `double jitterRatio` (0–1)

## Edge Cases & Handling
| Scenario | Expected Behavior |
|----------|-------------------|
| Invalid content-type | Immediate error state (no retry unless configured) |
| Missing boundary param | Error (cannot parse multipart) |
| Oversized frame | Drop frame, increment `droppedFrames`, continue stream |
| Truncated JPEG (EOI missing) | Attempt decode; if fails, drop & warn |
| Network disconnect mid-frame | Emit error & attempt reconnect (resume entire stream) |
| Rapid connect/disconnect taps | Debounce commands; ensure idempotent controller state |
| FPS > target | Drop intermediate frames, keep most recent |

## Testing Strategy Detail
- Parser uses dependency-injected `ChunkSource` for deterministic unit tests.
- Fake server utility: serves scripted sequence of (delay, partHeaders, jpegBytes) → generates multipart payload on the fly.
- Use golden JPEG fixtures (very small 1x1 / 2x2) to minimize test overhead.
- Inject fake clock to force stall detection paths quickly.

## Metrics & Instrumentation
- Counters: totalFrames, droppedFrames, errorCount, reconnectCount.
- Gauges: fps (sliding window), lastFrameAge.
- Distribution (optional): parseTimeMs (dev build only).

## Definition of Done (DoD)
1. Real camera URL (developer-provided) displays live updating frames in app for at least 60 seconds without memory growth > 5% baseline.
2. Handles forced disconnect (simulated server stop) and successfully reconnects within configured backoff window.
3. Unit + integration + widget tests all green (≥ 90% coverage of parser & controller logic paths).
4. Feature flag off keeps prior simulation path working (legacy tests unchanged).
5. Basic metrics (fps, frames received, last error) visible via overlay (frames & fps shown; last error via banner).
6. No uncaught exceptions during normal streaming & graceful stop.
7. Documentation updated: usage, configuration, troubleshooting.

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Parser complexity bugs | Frame loss / crashes | Extensive unit tests with malformed cases |
| High CPU from parsing | Battery / performance issues | Optional isolate & frame drop strategy |
| Memory churn (many Uint8Lists) | GC pauses | Buffer pooling (phase 6) |
| Flaky reconnects | Poor UX | Deterministic retry policy + telemetry |
| Web platform CORS failures | Stream unusable | Document CORS requirements; fallback guidance |
| Large frames from camera | OOM risk | `maxFrameBytes` enforcement |

## Rollout Plan
1. Land behind feature flag disabled by default.
2. Internal QA with test camera URL.
3. Enable for beta testers via remote config (if available) or build flavor.
4. Monitor logs/metrics; gather performance baselines.
5. Remove flag & deprecate simulation path once stable.

## Follow-Up (Post-DoD Enhancements)
- Frame caching & rewind last N frames.
- Multi-camera selection & switching.
- Authentication (Basic / Token / Query-signed URLs).
- Alternate protocols (HLS / WebRTC) exploration.
- Adaptive frame skipping based on UI visibility.

---
Reopened Plan Added: 2025-09-25

## External Libraries to Consider
| Purpose | Candidate | Rationale |
|---------|----------|-----------|
| HTTP streaming (fine control) | Built-in `HttpClient` | Lowest dependency surface, control over headers & chunking |
| Simplified HTTP & cross-platform | `http` + `http/browser_client.dart` | Easier on web; still need manual boundary parsing |
| Multipart parsing helper | (Custom) | Few maintained Dart libs handle continuous MJPEG multipart streams well; custom lightweight parser recommended |
| Image processing optimization (optional) | `image` | Could preprocess frames, though raw pass-through usually fine |
| Isolate management (optional) | `isolate_handler` / raw `Isolate` | Offload parsing if CPU spikes |
| Connectivity awareness | `connectivity_plus` | Provide user feedback on network conditions before/after connect |

At this time no third-party library cleanly abstracts MJPEG multipart streaming without trade-offs; a custom parser (≈150–250 LOC) is recommended for clarity and control.

## Proposed Next Implementation Slice (If Resumed)
1. Add `mjpegStreamProvider` (StreamProvider<Uint8List?>) fed by a new `MjpegStreamController` service
2. Implement `MjpegStreamController.start(url)` → returns Stream<FrameEvent>
3. Extend `VideoState` with: `hasError`, `errorMessage`, `framesReceived`, `lastFrameTime`
4. Replace placeholder with dynamic `Image.memory` binding to last frame
5. Add integration test using a fixture-based fake stream

## Completion Criteria for TASK006
All the goals in the table marked Done plus documentation + tests (achieved). Real streaming intentionally deferred to a future task (TASK007 candidate).

## Outcomes
Implemented initial real MJPEG streaming path under a feature flag:
- Added `Env.enableRealMjpeg` (REAL_MJPEG env var) to toggle real network streaming.
- Created `MjpegStreamController` with basic HTTP acquisition & multipart parsing.
- Extended `VideoState` to include frame bytes, counters, and error message.
- Updated `VideoPage` to render live frames & stats overlay when flag is enabled.
- Added fake MJPEG server and parser/unit/integration tests (flag-conditional).

Deferred (future task): reconnect policies, stall detection, FPS limiting, isolate offload, metrics provider.

Simulation path preserved (all pre-existing tests remain green with flag disabled).

To enable real streaming locally:
1. Add to `.env`: `REAL_MJPEG=true` and set `MJPEG_URL=http://your-camera/stream` OR
2. Export in shell: `export REAL_MJPEG=true` before running the app/tests.

When disabled (default), the app uses the original simulated state machine.

## Links
- Testing Guide: `docs/testing/mjpeg-streaming-testing-guide.md`
- Video Page: `lib/presentation/pages/video_page.dart`
- Tests: `test/unit/video_state_test.dart`, `test/integration/video_streaming_test.dart`, `test/presentation/pages/video_page_test.dart`

---
Last Updated: 2025-09-25
