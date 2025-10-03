# TASK013: Production Readiness Hardening

## Status: 📝 PLANNED

**Priority**: HIGH  
**Assigned**: GitHub Copilot  
**Started**: 2025-10-03  
**Completed**: -  

---
## Original Request
Transition the Hydroponic Monitor from demo-friendly behavior to production readiness by:
1. Eliminating simulated / dummy sensor data fallbacks (Influx & historical queries) so outages are visible.
2. Surfacing authentic, granular service health (MQTT, InfluxDB, MJPEG Video) plus an aggregate status.
3. Defaulting MJPEG to the deployed real stream (simulation only via explicit flag).
4. Ensuring the UI starts in a true "No Data" state until real telemetry (historical or live) arrives.
5. Introducing Data Quality semantics (none, partial, live, stale) and displaying them in the sensor UI.
6. Strengthening manual reconnect UX with per-service result feedback.
7. Hardening logging/observability for operational diagnosis while preserving security (no secret leakage).
8. Preparing architecture for upcoming historical charting (TASK011) without relying on dummy data.

---
## Thought Process
Production readiness requires replacing silent demo conveniences with explicit health signaling. Dummy data currently masks failures (especially Influx). We need a health + data quality model to ensure the UI truthfully reflects system state and provides operators actionable insight. We'll phase out dummy fallbacks safely (temporary dev flag), add health classification providers, upgrade tiles to display waiting vs historical vs live vs stale, and enhance the connection banner. The approach preserves developer ergonomics via injectible strategies and environment flags during migration while ensuring production builds expose real conditions.

### Key Considerations
- Avoid user confusion: differentiate "Waiting…" (expecting first packet) vs "No Data" (service unreachable / none stored)
- Prevent log noise: emit health transitions only on state change
- Ensure test determinism: inject time & thresholds for video/sensor classification
- Maintain security: never log tokens/passwords; mask config representations
- Provide incremental rollout (ALLOW_DUMMY_DATA flag) to keep CI green during transition

---
## Implementation Plan
1. Health Model
   - Add `ServiceStatus { initializing, healthy, degraded, unreachable }` & `DataQuality { none, partial, live, stale }` enums.
   - Implement health classifier services & Riverpod providers for MQTT, Influx, Video, plus aggregate provider.
2. Influx Refactor
   - Remove unconditional dummy generation; return Failure on init/query errors.
   - Add circuit-breaker style consecutive failure counter to classify `unreachable`.
   - Introduce optional `DummyDataStrategy` (dev/test only) behind `ALLOW_DUMMY_DATA` flag.
3. Data Quality Layer
   - Track last live MQTT timestamp per sensor; last historical query timestamp.
   - Classify and expose via `sensorDataQualityProvider(SensorType)`.
4. Sensor UI Upgrade
   - Add `DataQualityChip` / status badge (Waiting, Historical, Live, Stale, Unreachable).
   - Adjust tile logic: initial Waiting…, fallback to Historical when available, show No Data if failure/no readings.
   - Implement real sparkline & trend calculation: maintain rolling window of recent values per sensor (live + optional historical backfill) to drive both arrow direction (slope) and a lightweight inline sparkline (replaces placeholder "Chart").
5. Video Health Integration
   - Flip default: real MJPEG enabled unless `REAL_MJPEG=false`.
   - Health mapping: connecting→initializing, waitingFirstFrame>threshold→degraded, timeout/error→unreachable, playing→healthy.
   - Add hysteresis to avoid flapping (e.g., require 2 degraded samples before state change).
6. Connection Banner Enhancement
   - Display per-service icons + aggregate status color.
   - After manual reconnect, show summary (e.g., MQTT ✓ Influx ✗ Video ✓).
7. Logging & Observability
   - Standardized tags: `Health/MQTT`, `Health/Influx`, `Health/Video`.
   - Log only transitions & include previous→next state and cause.
   - Optional simple metrics counters (attempts, successes, failures) for future diagnostics.
8. Configuration & Flags
   - Add env/dart-defines: `ALLOW_DUMMY_DATA` (temporary), `SENSOR_STALE_MINUTES` (default 5), video first-frame thresholds.
   - Validate & clamp values; expose via `Env`.
9. Testing Overhaul
   - Update existing tests to expect Failure (not dummy Success) when Influx absent.
   - Add classification tests (data quality & service health state transitions).
   - Integration: simulate Influx outage, MQTT drop, video timeout.
   - Widget tests for all tile chips & banner multi-status rendering.
10. Documentation & Memory Bank
   - Update `systemPatterns.md`, `techContext.md`, `activeContext.md`, `progress.md` with new health/data quality model.
   - Add acceptance criteria & removal notice for dummy data.
11. Cleanup Phase
   - Remove `ALLOW_DUMMY_DATA` flag after stable release (tracked follow-up subtask).

---
## Acceptance Criteria
- No dummy sensor data returned in production when Influx is uninitialized or failing.
- Sensor tiles accurately display one of: Waiting…, Historical, Live, Stale, No Data (Influx unreachable or empty), with accessible labeling.
 - Sensor tiles show real trend arrow (derived from numeric slope over rolling window) and sparkline visual based on last N readings (no static placeholder).
- Health providers emit correct transitions (validated by tests) for MQTT, Influx, Video.
- Connection banner shows per-service statuses & aggregate indicator.
- Default video mode uses real stream; simulation only with explicit flag.
- Manual reconnect returns granular result (per-service) and updates banner promptly.
- Structured logs include each health state change exactly once per transition (prev→next) without secrets.
- All updated unit, widget, and integration tests pass; removed reliance on production dummy fallbacks.
- Memory bank files updated to reflect architecture change.

---
## Subtasks
| ID   | Description | Status | Updated | Notes |
|------|-------------|--------|---------|-------|
| 1.1  | Add enums `ServiceStatus`, `DataQuality` | Pending | - | Domain layer addition |
| 1.2  | Implement health providers (MQTT/Influx/Video) | Pending | - | Riverpod + classification logic |
| 1.3  | Aggregate overall service health provider | Pending | - | Worst-of logic w/ ordering |
| 2.1  | Remove Influx dummy auto fallback (primary queries) | Pending | - | Behind ALLOW_DUMMY_DATA flag initially |
| 2.2  | Add circuit-breaker failure counter in `InfluxService` | Pending | - | Threshold configurable |
| 2.3  | Introduce optional `DummyDataStrategy` injection (tests) | Pending | - | Provider override |
| 3.1  | Track per-sensor timestamps & classify DataQuality | Pending | - | Leverage existing providers |
| 4.1  | Build `DataQualityChip` widget | Pending | - | Color + tooltip mapping |
| 4.2  | Refactor `SensorPage` tile logic to new model | Pending | - | Remove hasSensorDataProvider coupling |
| 4.3  | Implement real sparkline & trend window provider | Pending | - | Rolling buffer + slope calc |
| 5.1  | Flip MJPEG real-stream default & add health mapping | Pending | - | Env + provider updates |
| 6.1  | Extend connection banner with multi-status icons | Pending | - | UI & provider wiring |
| 6.2  | Reconnect summary feedback (snackbar/toast) | Pending | - | Includes ✓ / ✗ per service |
| 7.1  | Implement transition logging & metrics counters | Pending | - | Deduplicate logs |
| 8.1  | Add new env flags & parses in `Env` | Pending | - | Safe parsing & defaults |
| 9.1  | Update/replace unit tests (Influx failure cases) | Pending | - | Expect Failure now |
| 9.2  | Add health & data quality classification tests | Pending | - | Deterministic timestamps |
| 9.3  | Integration test: Influx outage & MQTT drop | Pending | - | Docker orchestrated |
| 9.4  | Widget tests for chips & banner statuses | Pending | - | Accessibility labels |
| 9.5  | Sparkline & trend provider tests | Pending | - | Deterministic rolling window |
| 10.1 | Documentation updates (patterns/tech/progress) | Pending | - | Include diagrams |
| 10.2 | Update `activeContext.md` with transition status | Pending | - | After core landing |
| 11.1 | Remove ALLOW_DUMMY_DATA flag (cleanup) | Pending | - | Post-stabilization |

---
## Progress Log
### [2025-10-03]
- 📌 Task file created with detailed implementation & acceptance criteria.
- ✅ Comprehensive plan produced (see TASK013) aligning with removal of dummy data and health surfacing.
- ⏭ Next: Begin with enums & health providers (Subtasks 1.1–1.3).

---
## Verification Plan
Follow canonical `testing-procedure.md`:
1. Run unit tests after adding enums/providers.
2. Add failing tests for current dummy fallback (red) → implement removal (green).
3. Integration tests simulate service outages; verify health transitions & UI states.
4. Accessibility audit: sensor tiles & banner ARIA labels for status chips.
5. Review logs to confirm single transition line per state change.

Completion requires all acceptance criteria satisfied and full test suite green.

---
## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Empty dashboard surprises users | Perceived regression | Onboarding tooltip + clear status chips |
| Flapping health states | Log noise / UX churn | Hysteresis & debounce of transitions |
| Test flakiness (timers) | CI instability | Inject time sources & thresholds |
| Overly verbose logs | Harder ops visibility | Transition-only logging |
| Partial outages hidden | Slow detection | Multi-service icons + aggregate badge |

---
## Future Follow-Ups (Post TASK013)
- Diagnostics panel with real-time health metrics.
- Export health metrics via simple HTTP or MQTT topic.
- Persist last known healthy timestamp for each service.

---
## References
- TASK012 (existing production-ready scope baseline)
- TASK011 (upcoming historical charts integration)
- `systemPatterns.md`, `techContext.md` (to be updated)

> This task replaces silent demo conveniences with explicit operational visibility while retaining a safe, phased migration path.
