# TASK008: Dashboard Refresh → Manual MQTT & InfluxDB Reconnect

Status: REQUESTED
Priority: Medium
Created: 2025-09-25
Owner: (Unassigned)
Depends On: TASK004 (Real-time sensor streaming), TASK005 (Actuator control foundation)
Related: Connection management patterns in `systemPatterns.md`

## Motivation
The current dashboard "Refresh" (or planned refresh action) only triggers UI/state updates (or is a placeholder). Operators occasionally experience intermittent loss of either:
- MQTT broker connectivity (network blip, broker restart, dropped WebSocket/TCP session)
- InfluxDB query/session errors (transient network issues, server restart, token expiry in future)

A manual retry mechanism allows the user to force re-initialization without waiting for automatic backoff, accelerating operational recovery and improving perceived reliability.

## Problem Statement
When data appears stale or connection indicators show a degraded state, users have no single action to:
1. Re-initialize MQTT client (teardown + reconnect handshake)
2. Re-test and rebind InfluxDB client/query layer
3. Surface immediate feedback (success, still failing, partial failures)

## Objectives
1. Repurpose / augment the dashboard refresh button to perform an orchestrated manual reconnection attempt.
2. Provide granular feedback: MQTT reconnected, InfluxDB reconnected, partial failure messaging.
3. Non-blocking UI: operation shows progress indicator but does not freeze main thread.
4. Safe to invoke repeatedly (idempotent + internal throttling to avoid hammering services).
5. Log structured outcome (success/failure + timing) for diagnostics.

## Non-Objectives (Deferred)
- Automatic adaptive backoff tuning (handled by existing connection auto-retry logic).
- Credential/token renewal flows (future auth integration task).
- Offline caching / queueing of sensor data or actuator commands.

## User Story
As an operator, when live data or device statuses stop updating, I want to click a single Refresh button that intentionally re-establishes both MQTT and InfluxDB connections so I can quickly restore real-time monitoring without restarting the application.

## Proposed Approach
1. Introduce a `ConnectionRecoveryService` (or extend existing connection manager) exposing:
   - `Future<ReconnectResult> manualReconnect({bool force = false})`
   - Internally:
     a. Cancels and disposes existing MQTT client (await full close)
     b. Recreates client and subscribes required topics
     c. Pings / health-checks InfluxDB (simple lightweight query, e.g. `from(bucket: _health) |> range(start: -1m) |> limit(n:1)` or existing ping endpoint)
2. Provide a combined result object:
   ```dart
   class ReconnectResult {
     final bool mqttOk;
     final bool influxOk;
     final Duration elapsed;
     final String? errorMessage; // present if either failed
   }
   ```
3. UI Integration:
   - Dashboard AppBar / toolbar Refresh button triggers notifier method `attemptManualReconnect()`.
   - While in-flight: show spinner (icon morph or overlay) + tooltip "Reconnecting…".
   - Upon completion: success toast/snackbar if both OK; warning if partial; error banner if both failed.
4. State Management:
   - Add provider (e.g. `manualReconnectStatusProvider`) holding last attempt time, inProgress flag, last result.
   - Throttle: if a reconnect occurred < 5s ago and still in progress or just completed, disable or show tooltip "Please wait…".
5. Logging & Metrics:
   - Structured log entry: category `connectivity.manual_reconnect` with fields {mqttOk, influxOk, elapsedMs, error}.
   - (Future) Expose counters for manual attempts vs automatic retries.

## Edge Cases
| Scenario | Expected Behavior |
|----------|-------------------|
| User clicks rapidly 5 times | Only one active attempt; subsequent clicks ignored or queued (UI disabled) |
| MQTT reconnects, InfluxDB still down | Show partial success message, keep retry option enabled |
| Both already healthy | Fast path: do minimal health check (<250ms) then success snackbar |
| Reconnect during existing auto-retry | Merge logic: cancel/reset auto path safely or allow concurrent if safe (prefer cancel) |
| Failure due to bad credentials | Surface explicit auth error (future enhancement) |

## Acceptance Criteria
1. Clicking Refresh triggers real reconnection attempts (validated by disposing the old MQTT client and constructing a new instance; topics resubscribed).
2. InfluxDB health check performed and result surfaced.
3. UI communicates distinct outcomes: success, partial, failure.
4. Operation is idempotent and guarded against spam (throttled or disabled while running).
5. No uncaught exceptions; analyzer/test suite passes.
6. Structured logs produced for each attempt.

## Testing Strategy
- Unit:
  - `ConnectionRecoveryService` success path, MQTT fail, Influx fail, both fail.
  - Throttle logic (<5s consecutive attempts).
- Provider tests: state transitions (idle -> inProgress -> done) and result caching.
- Widget test: tapping refresh updates UI (loading state) and displays snackbar.
- Integration test (optional initial phase): simulate MQTT disconnect then manual reconnect triggers resubscription callbacks (mock).

## Implementation Steps
1. Define `ReconnectResult` model.
2. Implement `ConnectionRecoveryService.manualReconnect()` with injected abstractions:
   - `IMqttManager` (close/start/subscribe)
   - `IInfluxHealthChecker` (ping or test query)
3. Add Riverpod provider(s) for service + status.
4. Wire Dashboard refresh button to call notifier method.
5. Add UI feedback (loading state + snackbar / banner).
6. Add logging via existing `logger.dart` utility.
7. Write unit + provider tests.
8. Update memory bank references (systemPatterns.md / techContext.md if new patterns introduced).

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|-----------|
| Race with auto-reconnect | Duplicate clients | Use mutex / in-progress guard before constructing new client |
| Long Influx check stalls UI | Perceived hang | Use timeout (e.g. 3s) and treat timeout as failure with message |
| Partial recovery confusion | User uncertainty | Explicit partial success message with guidance to retry |
| Retrying during credential issues | Repeated failures | Detect auth errors and surface actionable guidance |

## Follow-Up (Future Tasks)
- TASK0XX: Auto fallback to exponential backoff after repeated manual failures.
- TASK0XX: Integrate metrics panel showing connection uptime and retry counts.
- TASK0XX: Add option to also reinitialize video stream controller.

## Definition of Done
- Feature documented here and indexed.
- Implementation PR adds service, providers, UI wiring, tests.
- Refresh button triggers manual reconnect producing observable state transitions and user feedback.
- Logs confirm reconnect attempts with outcomes.

---
Last Updated: 2025-09-25
