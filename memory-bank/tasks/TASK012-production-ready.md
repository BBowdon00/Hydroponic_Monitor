# TASK012: Production Readiness Hardening

## Status: ⏳ REQUESTED

**Priority**: CRITICAL  
**Assigned**: (Unassigned)  
**Created**: 2025-09-26  
**Depends On**: TASK004 (Live sensor streaming foundation), TASK005 (Actuator status plumbing), TASK007 (Video streaming UX), pending TASK008 (Reconnect hooks)  
**Related**: `lib/data/influx/influx_service.dart`, `lib/data/repos/sensor_repository.dart`, `lib/presentation/providers/connection_status_provider.dart`, `lib/presentation/providers/sensor_providers.dart`, `lib/presentation/pages/dashboard_page.dart`, `lib/presentation/widgets/sensor_tile.dart`, `lib/presentation/pages/video_page.dart`, `lib/core/env.dart`, `.env` template

## Original Request
Plan how to move the Hydroponic Monitor from demo mode to production readiness by eliminating simulated sensor data, surfacing true service health, defaulting video to the deployed stream, and ensuring the UI starts in a "No Data" state until real telemetry arrives.

## Thought Process
1. **Stop masking infrastructure issues.** InfluxDB currently manufactures dummy responses when the service is offline, which hides outages and prevents operators from understanding the system state. We need hard failure signals that ripple up to providers and the dashboard.
2. **Improve user-facing feedback loops.** The dashboard should show explicit "No Data" or disconnection states per sensor/service instead of optimistic placeholders so growers can react quickly.
3. **Align defaults with deployment.** The MJPEG stream should honor the production `.env` default (`http://raspberrypi:8000/stream.mjpg`), and connection widgets should leverage upcoming reconnect hooks once TASK008 lands.
4. **Guard against regressions.** Tests must cover the new failure pathways so we do not reintroduce fake data paths and to ensure UI copy reflects disconnected states.

## Implementation Plan
1. **Harden InfluxDB & Repository Layers**  
   - Remove `_generateDummySensorData` fallbacks from `InfluxDbService.querySensorData` and `queryLatestSensorData`; return `Failure` objects with specific error types when the client is uninitialized or queries fail.  
   - Emit granular connection status updates (`connecting`, `connected`, `degraded`, `disconnected`) via `connectionStream` so providers can distinguish startup vs. failure.  
   - Update `SensorRepository.initialize` to tolerate Influx initialization failures by disabling historical calls while keeping MQTT live, and surface a structured error so UI/providers can react without crashing.  
   - Introduce lightweight `InfluxUnavailableError` to differentiate from query exceptions (update `core/errors.dart`).

2. **Propagate Service Health to Providers & UI**  
   - Extend `connectionStatusProvider` to expose richer enums plus human-readable messages; update `ConnectionNotification` widget (and dashboard action) to display the specific service(s) offline.  
   - Adjust `sensor_providers.dart` so `hasSensorDataProvider` reflects actual data presence but dashboard tiles show `"No Data"` (or `"N/A"` for unitless values) whenever repositories report `Failure` or empty results.  
   - Refine `DashboardPage._buildSensorTile` to:  
     * Use provider-derived status to choose between `"No Data"`, `"Waiting"`, or real values.  
     * Display a secondary badge when the underlying service is disconnected (tied to `connectionStatusProvider`).

3. **Video Stream Defaults & Settings Alignment**  
   - Update `Env.mjpegUrl` default to `http://raspberrypi:8000/stream.mjpg` and seed `VideoStateNotifier` with `Env.mjpegUrl` instead of a hard-coded IP.  
   - Refresh `.env.example` / docs to highlight the default stream endpoint and how to override it.  
   - Confirm `video_page.dart` gracefully handles empty URLs by disabling the connect button until a valid URI is provided.

4. **UI/UX Enhancements for Disconnected States**  
   - Update `SensorTile` (or wrap it) to support an inset warning/"Disconnected" banner when data is unavailable due to service health.  
   - Ensure status badges on the dashboard reflect partial outages (e.g., MQTT ok but Influx down).  
   - Add copy to the video page and dashboard modals clarifying when data is unavailable versus still loading.

5. **Testing & Verification**  
   - Add unit tests for `InfluxDbService` covering uninitialized client, failed queries, and new status signaling.  
   - Extend provider tests to verify `hasSensorDataProvider`, `latestSensorReadingsProvider`, and `connectionStatusProvider` behavior when InfluxDB is offline.  
   - Add widget tests for `DashboardPage` to assert "No Data" and disconnection states render correctly.  
   - Run analyzer + unit/widget suites via `flutter analyze` and `./scripts/test-runner.sh --unit`; document how to exercise manual smoke tests with a real broker/Influx instance.

## Acceptance Criteria
- No production code path generates synthetic sensor readings; services return explicit errors when unavailable.  
- Dashboard tiles default to `"No Data"/"N/A"` until real readings arrive and visibly flag service outages.  
- Connection dialogs/banners identify which backend is disconnected.  
- Video stream defaults to the `.env` configured MJPEG URL (`http://raspberrypi:8000/stream.mjpg`).  
- Automated tests cover service-failure scenarios and pass locally.

## Progress Tracking
| ID | Description | Status | Notes |
|----|-------------|--------|-------|
| 1.1 | Remove dummy data fallbacks & add explicit Influx error types | ☐ Not Started | Update `InfluxDbService` + errors | 
| 1.2 | Propagate service status through repositories/providers | ☐ Not Started | `SensorRepository`, `connectionStatusProvider`, `sensor_providers.dart` |
| 1.3 | Refresh dashboard/video UI to show No Data & default stream | ☐ Not Started | `DashboardPage`, `SensorTile`, `video_page.dart`, `Env` |
| 1.4 | Extend documentation & defaults (.env, README) | ☐ Not Started | Highlight new production defaults |
| 1.5 | Test coverage for failure modes & UI states | ☐ Not Started | Unit + widget + provider tests |

## Progress Log
### [2025-09-26]
- 📝 Drafted production readiness hardening plan covering service health, UI updates, and test strategy.
