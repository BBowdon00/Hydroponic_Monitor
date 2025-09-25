# TASK007: Web-Compatible MJPEG Streaming & UI State Cleanup

Status: COMPLETED
Priority: High
Created: 2025-09-25
Owner: GitHub Copilot
Depends On: TASK006 (baseline streaming controller & feature flag)

## Motivation
Current real MJPEG implementation works only on dart:io platforms. On Flutter Web, the controller emits an unsupported error and the UI falls back to placeholder text that can be misleading ("Live Video Stream", "Connected to <url>"). We need a true web streaming path plus accurate UI states without fake placeholder marketing copy.

## Objectives
1. Implement a web-compatible MJPEG stream acquisition path (no dart:io).
2. Remove misleading placeholder texts; only show states that reflect reality.
3. Unify state model: disconnected, connecting, waitingFirstFrame, playing, error.
4. Preserve existing native (IO) behavior while adding web path.
5. Maintain feature flag `REAL_MJPEG`; when disabled still allow simulation mode but clearly labeled.
 6. Enforce fast connection failure: 5-second timeout transitioning to error state (implemented 2025-09-25).

## Non-Objectives (This Task)
- Advanced reconnect/backoff policies (deferred to resilience task).
- FPS smoothing / isolate parsing optimization (future performance task).
- Multi-camera switching; authentication headers.

## Summary / Outcomes
Implemented unified phase-based MJPEG streaming with web compatibility and fast-fail timeout. Added 5s connection timeout, simulation mode labeling, and updated UI states (idle, connecting, waitingFirstFrame, playing, error). Tests updated and passing; no analyzer warnings. Feature flag preserves ability to disable real streaming.

## Original Proposed Approach (for record)
### 1. Controller Abstraction
Introduce conditional implementation files:
- `mjpeg_stream_controller_io.dart` – existing HttpClient-based implementation (migrated from current file).
- `mjpeg_stream_controller_web.dart` – new implementation.
- `mjpeg_stream_controller.dart` – conditional export wrapper.

### 2. Web Implementation (Phase 1: Simple Image Element)
Use browser's native multipart handling by rendering `<img src="/mjpeg">`. Wrap via `Image.network(streamUrl)` and attach an `ImageStreamListener` to:
- Fire `StreamStarted` when the first chunk begins (optimistic or on first frame decode).
- Increment frame counter on each new image decode event if feasible (may not fire per MJPEG part; acceptable initially).
- Fire `StreamError` on network image failure.
Limitations documented; can upgrade to manual boundary parsing later.

### 3. Optional Phase 2 (Deferred Unless Needed Now)
Manual boundary parsing using `package:http/browser_client.dart` streaming body; reuse parser logic extracted into a shared mixin / helper.

### 4. State Model Updates
Augment `VideoState`:
- Remove placeholder textual banners.
- Add derived getters: `isWaitingFirstFrame => isConnected && lastFrame == null`.
- Add `bool hasAttempted` to differentiate initial idle vs post-connect failure.
- Add explicit `VideoConnectionPhase { idle, connecting, waitingFirstFrame, playing, error }` (enum) OR rely on flags + derived logic.

### 5. UI Changes (`video_page.dart`)
- Replace simulated placeholder with minimal states:
  - idle: icon + "No stream connected" + URL input
  - connecting: spinner + message
  - waitingFirstFrame: spinner + "Waiting for first frame…"
  - error: error text + Retry button (disabled while connecting)
  - playing: frame + overlays
- Only show fullscreen & stats overlays in `playing` phase.
- Simulation mode (flag off): show a small badge "Simulation Mode" instead of implying real stream.

### 6. Simulation Path Cleanup
- When `Env.enableRealMjpeg == false`, still allow connect button to transition to simulated connected state (for existing tests) **BUT** do not display misleading live copy; show badge.

### 7. Testing
- Widget tests updated: assert new state labels (idle, connecting, waiting, error, playing).
- Guard web-specific behavior with `kIsWeb`; where environment not web, skip or simulate.
- Add unit test for derived `isWaitingFirstFrame`.

### 8. Documentation
- Update TASK006 or cross-link noting that web support is now provided in TASK007.
- Add section in README or a short `docs/video-streaming.md` explaining platform behaviors & limitations.

## Acceptance Criteria
1. On web with `REAL_MJPEG=true`, app attempts real connection without throwing `UnsupportedError`.
2. UI never shows "Live Video Stream" or "Connected to <url>" placeholders in absence of frames.
3. Distinct visual states for idle, connecting, waitingFirstFrame, playing, and error.
4. Existing tests pass; new tests cover waitingFirstFrame & error states.
 5. Connection attempts exceeding 5s without first frame trigger error with explicit timeout message.
 6. No analyzer warnings; conditional imports compile for web & io.

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|-----------|
| Image.network doesn't trigger per-frame events | Inaccurate FPS | Accept & display N/A or 0 on web until manual parser added. |
| CORS blocked MJPEG URL | Stream fails | Surface explicit error; document CORS requirement. |
| Conditional import misconfiguration | Build errors | Add `// ignore_for_file: implementation_imports` only if necessary & test both `flutter build web` and `flutter build apk`. |

## Follow-Up Tasks (Future)
- TASK008: Reconnection & stall detection.
- TASK009: True FPS calculation & frame pacing.
- TASK010: Manual web parser for consistent stats.

## Implementation Steps Checklist (Final)
- [x] Extract IO controller to `mjpeg_stream_controller_io.dart`.
- [x] Create web controller file with basic fetch/stream (upgraded from simple Image.network concept).
- [x] Conditional export file.
- [x] Update state model & notifier logic (phases + timeout).
- [x] Update UI states & remove placeholder text.
- [x] Update / add tests (widget tests reflect new labels & phases).
- [x] Docs & memory bank updates.

## Timeline Estimate
~1 day initial (Phase 1) + additional time later for advanced parsing.

---
Last Updated: 2025-09-25 (Completed)
