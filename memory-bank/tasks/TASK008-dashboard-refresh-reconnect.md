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
4. Access connection controls consistently across pages (current dashboard-only placement hides refresh and signal controls elsewhere)

## Objectives
1. Relocate the dashboard connection controls (signal strength menu, Wi-Fi icon, Refresh action) into the persistent connection banner shown on every page.
2. Provide granular feedback: MQTT reconnected, InfluxDB reconnected, partial failure messaging.
3. Non-blocking UI: operation shows progress indicator but does not freeze main thread.
4. Safe to invoke repeatedly (idempotent + internal throttling to avoid hammering services).
5. Log structured outcome (success/failure + timing) for diagnostics.
6. Maintain the banner at all times (even when healthy), tint it green when fully connected, and remove the countdown timer while keeping the Wi-Fi icon behavior consistent with the existing dashboard button.

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
   - Promote the connection banner so it is always rendered; in healthy state it presents success copy with green styling and no countdown timer.
   - Embed the Wi-Fi icon and connection signal menu within the banner; tapping the icon triggers `attemptManualReconnect()` identical to the current dashboard Wi-Fi button (long-press/menu still surfaces diagnostics).
   - Surface Refresh affordance inside the banner action row (spinner overlay during in-flight attempts, tooltip "Reconnecting…").
   - Upon completion: success toast/snackbar if both OK; warning if partial; error banner (red) if both failed, synchronized with banner messaging.
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
| User on non-dashboard page | Banner remains present with Wi-Fi icon + refresh affordance |

## Acceptance Criteria
1. Clicking Refresh triggers real reconnection attempts (validated by disposing the old MQTT client and constructing a new instance; topics resubscribed).
2. InfluxDB health check performed and result surfaced.
3. Connection banner remains visible when connected, switches to green styling without countdown timer, and co-locates signal menu + Wi-Fi icon + refresh action.
4. Wi-Fi icon in the banner invokes the same reconnect logic and diagnostics menu as the previous dashboard Wi-Fi button.
5. UI communicates distinct outcomes: success, partial, failure (banner + snackbar states).
6. Operation is idempotent and guarded against spam (throttled or disabled while running).
7. No uncaught exceptions; analyzer/test suite passes.
8. Structured logs produced for each attempt.

## Testing Strategy
- Unit:
  - `ConnectionRecoveryService` success path, MQTT fail, Influx fail, both fail.
  - Throttle logic (<5s consecutive attempts).
- Provider tests: state transitions (idle -> inProgress -> done) and result caching.
- Widget test: persistent banner renders in healthy + degraded states, Wi-Fi icon/refresh affordance trigger loading state and snackbar.
- Integration test (optional initial phase): simulate MQTT disconnect then manual reconnect triggers resubscription callbacks (mock).

## Implementation Steps
1. Define `ReconnectResult` model.
2. Implement `ConnectionRecoveryService.manualReconnect()` with injected abstractions:
   - `IMqttManager` (close/start/subscribe)
   - `IInfluxHealthChecker` (ping or test query)
3. Add Riverpod provider(s) for service + status.
4. Move connection controls from the dashboard AppBar into the shared `ConnectionNotification` (or equivalent banner widget) rendered on all pages.
5. Ensure banner styling supports connected (green, subtle) vs degraded (amber/red) states without countdown timer.
6. Bind Wi-Fi icon tap/press gestures to manual reconnect logic; preserve diagnostics menu behavior inside the banner placement.
7. Add UI feedback (loading state + snackbar / banner).
8. Add logging via existing `logger.dart` utility.
9. Write unit + provider tests.
10. Update memory bank references (systemPatterns.md / techContext.md if new patterns introduced).

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
Last Updated: 2025-09-26
