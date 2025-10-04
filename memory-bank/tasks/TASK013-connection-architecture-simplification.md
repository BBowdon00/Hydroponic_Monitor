# TASK013: Connection Architecture Simplification & First-Load Reliability

Status: 🚧 PROPOSED
Priority: High
Created: 2025-10-04
Owner: GitHub Copilot
Depends On: TASK008 (Manual reconnect), TASK010 (Runtime config), TASK012 (Production readiness hardening – partial overlap)
Related: `mqtt_service.dart`, `sensor_repository.dart`, `data_providers.dart`, `connection_status_provider.dart`, `influx_service.dart`

## Motivation
Recent browser session logs reveal:
1. Multiple MQTT connection attempts (attempt #1/#2) before success, interleaved with repository disposal/recreation.
2. Redundant & noisy logging ("MQTT client connected" → "Successfully connected..." → repository-level "MQTT connected successfully") without a single authoritative lifecycle event to providers.
3. Connection success not always emitted (UI stuck in disconnected state) – race between provider subscription & service callbacks.
4. Repository initialization soft-fails then enters a bad state (late Influx init failure after manual reconnect sequence) leading to: no sensor stream consumption, stale UI, and unbounded retry churn potential.
5. Manual reconnection works (attempt #3) but original initialization error path leaves inconsistent Influx state ("Bad state: Cannot add new events after calling close").
6. Placeholder MQTT service triggers an early (wasted) connect before the real runtime configuration loads, causing duplicated attempts.

## Problem Statement
Current connection orchestration spreads state across:
- `MqttService` (connect logic + callbacks + first subscription + manual replay)
- `SensorRepository` (initial connect + background retry loop + event waiting)
- Providers (`sensorRepositoryInitProvider`, `connectionStatusProvider`) layering additional waiting, replay, and health checks
- `ConnectionRecoveryService` (manual resets / reconnection flows)

This produces:
- Races: Status subscribers may attach after initial connected event; manual replay patches but is not deterministic.
- Double / triple logging layers with overlapping semantics.
- Multiple responsibility violations: Repository both orchestrates connectivity & domain persistence concerns.
- Hidden state corruption: Influx service re-init after dispose triggers stream closure errors.
- Difficulty guaranteeing exactly-once initial connect handshake.

## Objectives
1. Eliminate duplicate initial MQTT connects via config gating.
2. Reduce log noise to a concise, single-layer lifecycle (connect → success/fail → disconnect) without repository echo.
3. Ensure a reliable emission of a connected status (no missed first event) with a lightweight replay buffer.
4. Remove repository-owned MQTT retry loop; rely on library autoReconnect + manual reconnect button.
5. Prevent Influx stream misuse after dispose (guard & simplify init path).
6. Expose simple diagnostics (attempt counter + last failure) with minimal code.
7. Enforce ordering: config resolved → MQTT connected → repository initializes.

## Non-Objectives
- Authentication/token refresh flows (future task).
- Historical charts data querying (TASK011).
- Removal of manual reconnect UI (it remains, but simplified to call new orchestrator).

## Proposed Architecture Changes (Lightweight Provider Ordering)
Implement a single dedicated `FutureProvider<void>` that performs the first MQTT connection after configuration is ready. No coordinator class or state machine.

### A. Add `mqttConnectionProvider`
```dart
final mqttConnectionProvider = FutureProvider<void>((ref) async {
   // 1. Wait for runtime config (eliminates placeholder service churn)
   final _ = await ref.watch(configProvider.future);
   // 2. Acquire service (built with final config)
   final service = ref.watch(mqttServiceProvider);
   // 3. Connect once
   final sw = Stopwatch()..start();
   final attempt = service.incrementAttempt();
   final result = await service.connect();
   result.when(
      success: (_) => Logger.info('MQTT connected (attempt=$attempt, ms=${sw.elapsedMilliseconds})', tag: 'MQTT'),
      failure: (e) => Logger.error('MQTT connect failed (attempt=$attempt): $e', tag: 'MQTT'),
   );
   // 4. Optionally wait a brief moment for onConnected callback ordering if needed
});
```
This replaces the need for repository-init to call `connect()` directly.

### B. Adjust `sensorRepositoryInitProvider`
Await `mqttConnectionProvider` before initializing the repository so that MQTT is already connected (or has failed deterministically).

### C. Lightweight Replay / Status
Retain `connectionStatusProvider`; after subscribing, invoke `mqttService.emitCurrentStatus()` once (it replays last known state). Remove any unnecessary timers for MQTT.

### D. Remove Placeholder Branch
Delete placeholder path in `mqttServiceProvider`; provider construction will naturally suspend until `configProvider` resolves.

### E. Logging Simplification
Canonical log sequence per connect attempt: Connecting → Connected (with attempt & duration) OR Failure (with attempt & error) → Disconnected (when applicable). Remove repository-level success echo.

### F. Retry Strategy
Use library `autoReconnect` plus existing manual reconnect workflow. No custom backoff logic in this task.

### G. Influx Alignment
Optionally add an `influxConnectionProvider` later; for now leave existing initialization path but ensure disposal guards prevent closed-stream errors.

### H. Diagnostics Additions
Add to `MqttService`:
```dart
int _attempts = 0;
int incrementAttempt() => ++_attempts;
int get attemptCount => _attempts;
```
Expose in debugging UI later if desired.
### I. Removed Scope
Previous ideas for a full phase-based coordinator, unified event stream, adaptive backoff, and metrics dashboard are intentionally deferred and no longer part of this task’s plan.

## Edge Cases & Handling
| Scenario | Handling |
|----------|----------|
| Websocket connect success but no onConnected callback (current issue) | Add explicit timeout (e.g., 4s) after low-level connect future; treat missing callback as brokerUnresponsive failure & retry. |
| Multiple rapid manual reconnect clicks | Coordinator guards with mutex; subsequent calls return current in-flight Future. |
| Config change mid-connect | Transition to `Retiring`, cancel attempt, rebuild with new config, start fresh `Connecting`. |
| Influx health passes late after initial UI subscribe | Replay latest event ensures UI updates immediately. |
| Dispose while connecting | Cancel timers, close streams gracefully, set phase Idle. |

## Acceptance Criteria
1. Only one MQTT connect attempt occurs on cold start (unless it fails). Verified via log inspection and test harness.
2. Placeholder service connect attempt is eliminated (provider no longer constructs a temporary service that calls connect early).
3. Repository code no longer starts or manages an MQTT retry loop; related methods/fields removed.
4. Log output reduced to a single success line per successful connect attempt (no repository duplicate message).
5. `connectionStatusProvider` reflects connected state on first successful connect without manual reconnect.
6. Influx initialization does not throw "Cannot add new events after calling close" during reconnect/dispose scenarios.
7. Manual reconnect still functions (no regression) using existing recovery logic.
8. Attempt counter increments and appears in logs (attempt=1 on first connect, 2+ only after manual reconnect or library-level reconnect).
9. All existing tests pass after minor fixture updates (if they asserted old log strings or repository retry behavior).
10. Code clearly documents Phase 2 (optional full coordinator) path inside TASK013 (this file) without implementing it yet.

## Testing Strategy
### Unit
- `MqttService` attempt counter increments.
- Gated bootstrap: a test ensuring `mqttBootstrapProvider` doesn’t call connect until config future resolves.
- Removed retry loop: confirm no timers spawned in `SensorRepository` (can assert private field absence via reflection or rely on behavioral test: no additional connect logs over time when broker unreachable).

### Provider
- `mqttBootstrapProvider` awaited before repository init (prove by injecting a fake service counting connect calls).
- `connectionStatusProvider` receives a connected status exactly once on first connect.

### Integration
- Valid broker: single connect & sensor message delivered to UI; no duplicate success logs.
- Manual reconnect path triggers second connect (attempt=2) and resumes data flow.
- Influx dispose/re-init triggers no stream add-after-close errors (log scan or try-catch instrumentation).

### Regression
- Existing actuator control tests still pass (uses same MQTT publishing path).
- Video & unrelated providers unaffected (sanity build). 

## Implementation Steps
1. Remove placeholder branch from `mqttServiceProvider`; rely on config gating (provider suspends until ready).
2. Add attempt counter + `incrementAttempt()` to `MqttService`.
3. Create `mqttBootstrapProvider` (await config → invoke connect → log result). Ensure repository waits for this provider.
4. Modify `sensorRepositoryInitProvider`: remove direct `connect()` call; ensure it `await ref.watch(mqttBootstrapProvider.future)` before initialization.
5. Strip `_startMqttRetryLoop()` + related fields/timer logic from `SensorRepository`.
6. Prune duplicate MQTT success log in repository.
7. Verify `connectionStatusProvider` still works; remove any unneeded forced replay logic except a single `emitCurrentStatus()` call after subscription if necessary.
8. Add Influx bootstrap provider (optional in this phase) OR leave as-is if already deterministic.
9. Update tests asserting logs / behavior; add new unit/provider tests per strategy above.
10. Update docs (`systemPatterns.md`, `techContext.md`) with a short “Proto Coordinator Phase 1” subsection + future upgrade path.
11. Update this task file status to Completed with summary once merged.

## Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| Large refactor destabilizes existing tests | Incremental PR: introduce coordinator parallel to existing, then flip providers, then remove legacy code. |
| Missed edge around retirement causing ghost connects | Add defensive `phase == Retiring` checks prior to callback actions. |
| Web-specific timing differences | Use explicit callback + fallback timer pattern for connect readiness. |
| Increased complexity | Keep coordinator <250 LOC, exhaustive enum-driven phases, documented transitions. |

## Definition of Done
- Code merged with green test suite.
- Legacy retry logic removed; coordinator governs all connection transitions.
- Updated documentation & memory bank entries.
- First-load browser session reliably reaches Ready without manual intervention.

---
Last Updated: 2025-10-04
