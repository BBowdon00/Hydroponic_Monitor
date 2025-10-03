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
5. **Clarify environment boundaries.** Current environment handling is implicit. We need a clean separation between production (`.env` + root `docker-compose.yml`) and integration test (`.env.test` + `test/integration/docker-compose.yml`) configurations so tests never accidentally target live services and production defaults remain minimal & explicit.

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

6. **Environment & Configuration Simplification (Revised – Test Default)**  
    - Maintain dual files: `.env.test` (now treated as the DEFAULT when present) and `.env` (explicit production / staging).  
    - Introduce a production flag (compile/runtime) `APP_ENV=prod` (any other / empty value implies test) so builds/tests default to test isolation unless production is explicitly requested.  
    - Keep current implicit priority temporarily (test-first) but add logging so accidental production assumptions are visible; later enforce explicit selection (still defaulting to test).  
    - Root `docker-compose.yml` continues to use `.env`; integration stack uses `.env.test` explicitly.  
    - Provide script/Make target: `scripts/up-test-stack.sh` to spin up the integration environment with `.env.test`.  
    - Refactor `lib/core/env.dart` minimally (do NOT rename existing getters) to:  
       * Add `Env.appEnv` derived from `String.fromEnvironment('APP_ENV', defaultValue: 'test')`.  
       * If `appEnv == 'prod'` load `.env`; else load `.env.test` (fallback to `.env` only if test file missing).  
       * Add `Env.assertConfigured()` (debug only) logging missing required keys; non-fatal.  
    - Produce clearer examples: `.env.example` (production-safe template) and `.env.test.example` (isolated localhost/test-bucket) – current `.env` & `.env.test` will be aligned with those templates.  
    - README & DEPLOYMENT docs: emphasize safe default (test) and the explicit production flag for releases / demos.  
    - Tests: add coverage ensuring (a) default run without flag -> test bucket; (b) with `--dart-define=APP_ENV=prod` -> production bucket & urls; (c) absence of `.env.test` gracefully falls back to `.env` with a warning.

## Acceptance Criteria
- No production code path generates synthetic sensor readings; services return explicit errors when unavailable.  
- Dashboard tiles default to `"No Data"/"N/A"` until real readings arrive and visibly flag service outages.  
- Connection dialogs/banners identify which backend is disconnected.  
- Video stream defaults to the `.env` configured MJPEG URL (`http://raspberrypi:8000/stream.mjpg`).  
- Automated tests cover service-failure scenarios and pass locally.
- Environment separation: root compose uses `.env`; integration compose uses `.env.test`; no cross-contamination.  
- `Env.dart` refactored for clarity (straightforward static getters, minimal logic, documented required keys).  
- Example env files (`.env.example`, `.env.test.example`) are updated and referenced in docs.  
- A documented command/path exists to start the integration stack using test variables.

## Progress Tracking
| ID | Description | Status | Notes |
|----|-------------|--------|-------|
| 1.1 | Remove dummy data fallbacks & add explicit Influx error types | ☐ Not Started | Update `InfluxDbService` + errors | 
| 1.2 | Propagate service status through repositories/providers | ☐ Not Started | `SensorRepository`, `connectionStatusProvider`, `sensor_providers.dart` |
| 1.3 | Refresh dashboard/video UI to show No Data & default stream | ☐ Not Started | `DashboardPage`, `SensorTile`, `video_page.dart`, `Env` |
| 1.4 | Extend documentation & defaults (.env, README) | ☐ Not Started | Highlight new production defaults |
| 1.5 | Test coverage for failure modes & UI states | ☐ Not Started | Unit + widget + provider tests |
| 1.6 | Environment & docker-compose separation + Env.dart refactor | ☐ Not Started | Dual .env / .env.test, compose wiring, docs |

## Progress Log
### [2025-09-26]
- 📝 Drafted production readiness hardening plan covering service health, UI updates, and test strategy.

### [2025-10-03]
- 🔧 Added environment / docker-compose separation scope, Env.dart simplification objectives, and updated acceptance criteria.

## Recommended Environment Handling Solution (Design – Revised Test-First Default)

This section captures the selected approach for safe, explicit separation of production vs. integration test configuration and a simplified `Env` loading strategy. Implementation will occur under sub-task 1.6.

### Goals
1. Eliminate accidental preference for `.env.test` merely because it exists in assets.
2. Make the chosen environment explicit (fail-fast if an invalid env is requested).
3. Prevent shipping test secrets in production builds.
4. Provide deterministic, override-able values for CI, local dev, and integration tests.
5. Reduce complexity inside `Env.dart` while preserving flexibility for runtime overrides via real OS environment variables (especially in container deployments).

### Overview (Updated)
Introduce a single compile/runtime selector `APP_ENV` (values: `prod`, `test`, optional future `dev`). The selector defaults to `test` (safer) unless explicitly set to `prod`. The app chooses exactly one file:

| APP_ENV | File Loaded  | Intended Use                          | Notes |
|---------|--------------|---------------------------------------|-------|
| prod    | `.env`       | Production / staging / demos          | Must exclude test secrets |
| test(*) | `.env.test`  | Default (no flag), integration & CI   | Isolated buckets/hosts |

`(*)` Any value other than exact `prod` (including unset) is treated as `test`.

Fallback: If `APP_ENV=test` (default) but `.env.test` missing, attempt `.env` and log a structured warning (`ENV_LOAD_FALLBACK=test->prod`). If `APP_ENV=prod` but `.env` missing, proceed with hardcoded safe defaults and a warning.

### `Env.init()` (Planned Pseudocode – Revised)
```
static Future<void> init() async {
   const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'test');
   final isProd = appEnv == 'prod';
   final primaryFile = isProd ? '.env' : '.env.test';
   try {
      await dotenv.load(fileName: primaryFile);
      if (!isProd) debugPrint('ℹ Loaded test environment ($primaryFile)');
      if (isProd) debugPrint('ℹ Loaded production environment (.env)');
   } catch (e) {
      if (!isProd) {
         // Fallback: test file missing, try production
         try {
            await dotenv.load(fileName: '.env');
            debugPrint('⚠ test env file missing; fell back to .env');
         } catch (_) {
            debugPrint('⚠ No env file loaded; using built-in defaults');
         }
      } else {
         debugPrint('⚠ Production env file missing; using built-in defaults');
      }
   }
   Env.assertConfigured();
}
```

### `Env` Accessor Simplification
Each required variable receives a private getter helper that enforces presence (in debug) and falls back only to intentionally documented defaults. Example pattern:
```
static String _req(String key, {String? fallback}) {
   final v = dotenv.env[key] ?? const String.fromEnvironment(key) ?? fallback;
   assert(v != null && v!.isNotEmpty, 'Missing required env key: $key');
   return v!;
}
```
Then exposures: `mqttHost`, `mqttPort`, `influxUrl`, `influxOrg`, `influxBucket`, `influxToken`, `mjpegUrl`.

### Preventing Accidental Shipping of Test Env
1. Keep `.env.test` OUT of production asset bundle by default (only include for integration test builds if needed).  
2. Optionally maintain a `flutter_assets_test.yaml` (alt build config) or use a symbolic copy step in CI to include `.env.test` only for test commands.  
3. Document a guard: pipeline grep ensures `.env.test` not present in release artifact.

### Docker Compose Alignment
Root `docker-compose.yml`: uses `.env` automatically (Compose default) or explicit `env_file: .env`.  
Integration stack: `docker compose -f test/integration/docker-compose.yml --env-file .env.test up -d`.  
Scripts: add `scripts/up-test-stack.sh` executing the above + basic health checks (Influx readiness, Mosquitto port check).  

### Testing Strategy Addendum
1. Unit test verifying `APP_ENV=test` selects `.env.test` by stubbing `String.fromEnvironment` (via `--dart-define`).  
2. Widget smoke test asserts production default MJPEG URL when no env keys provided.  
3. Integration test ensures test bucket name (`test-bucket`) is selected with `.env.test`.  
4. Negative test: when `APP_ENV=test` but `.env.test` absent, code logs a warning and still returns default safe endpoints (no crash).  

### Migration Steps (When Implementing)
1. Create `.env.test.example` mirroring `.env.example` but with test-safe values (localhost broker, test bucket, ephemeral token placeholder).  
2. Refactor `Env.init()` to use explicit APP_ENV selection (remove current silent `.env.test` preference).  
3. Simplify getters (remove nested platform branching except where web requires).  
4. Update README + DEPLOYMENT docs with environment matrix and build command examples.  
5. Add CI steps: run unit tests with `--dart-define=APP_ENV=test`; run a release build with `--dart-define=APP_ENV=prod` ensuring `.env.test` not packaged.  
6. Add script `scripts/up-test-stack.sh`.  
7. Add asserts/log warnings via `Env.assertConfigured()` for required keys (`INFLUX_URL`, `MQTT_HOST`, etc.).  

### Acceptance Criteria Additions (Revised)
- Environment selection via `APP_ENV`; default = test; only `APP_ENV=prod` switches to production file.  
- Missing designated env file triggers documented fallback and warning (single occurrence).  
- Production artifacts do not package `.env.test`; test artifacts may include both but must log which loaded.  
- Documentation shows: (a) default test run, (b) explicit production build command.  

### Open Questions (To Resolve Before Implementing)
1. Do we want a `dev` flavor distinct from `prod` (e.g., enabling verbose logging)?  
2. Should `Env.assertConfigured()` escalate (throw) in test runs to catch missing keys early?  
3. Is a build-time lint (simple shell grep) acceptable in CI to enforce absence of `.env.test` in release builds?  
4. Any planned runtime secrets injection (e.g., Kubernetes secrets) requiring a secondary override layer?  

Answers can adjust sub-task 1.6 without changing core direction.

## Current Environment State Snapshot (Before Refactor)

This snapshot records the ACTUAL state of the repo as of 2025-10-03 to contrast with the planned design above.

### Files Present
- `.env` (checked in) – Contains production-domain hostnames but also includes test-oriented tokens (`INFLUX_TOKEN=test-token-for-integration-tests`, bucket `test-bucket`). Acts as a hybrid dev/prod file right now.
- `.env.test` (checked in) – Marked clearly for test; points some values to localhost (MQTT) but still overrides `INFLUX_URL` to production reverse proxy unless uncommented. Includes `TEST_ENV=true`.
- `lib/core/env.dart` – Current logic always TRIES `.env.test` first (silent priority) then falls back to `.env`. `APP_ENV` flag does NOT exist yet. `TEST_ENV` influences defaults (e.g., Influx URL & bucket).

### Current Loading Behavior
1. `Env.init()` tries `dotenv.load('.env.test')`; if it succeeds, `.env` is ignored.
2. Only if `.env.test` missing/not in assets does `.env` load.
3. No explicit environment selector; presence of `.env.test` drives behavior.
4. `TEST_ENV=true` in `.env.test` toggles fallback defaults (Influx: localhost:8086, bucket: test-bucket) if no explicit key present.

### Current Default Values
- `mqttHost`: hardcoded fallback `m0rb1d-server.mynetworksettings.com`
- `influxUrl` (web): default `http://m0rb1d-server.mynetworksettings.com:8080/influxdb`
- `influxUrl` (io): environment/platform override first, else `.env` value, else dynamic `_defaultInfluxUrl` (which uses localhost if `TEST_ENV=true`)
- `influxBucket`: default `grow_data` unless `isTest` true → `test-bucket`
- `mjpegUrl`: default `http://m0rb1d-server.mynetworksettings.com:8080/stream` (planned change later to `http://raspberrypi:8000/stream.mjpg` in acceptance criteria)

### Interaction With Config Layer
- `ConfigRepository` consumes `Env.*` only as LAST resort defaults when no persisted user configuration exists.
- Renaming getters (e.g., to `mqttBroker`) would break repository & providers; must retain existing names or refactor all usages together.
- No environment namespace for persisted keys yet (a future enhancement is optional but not required before hardening).

### Divergences From Planned Design (Now Revised)
| Aspect | Current | Revised Plan |
|--------|---------|-------------|
| File selection | Implicit .env.test priority | Explicit flag with test default + safe fallback |
| Default env | test if .env.test exists | test unless `APP_ENV=prod` |
| Prod selection | Not explicit | `--dart-define=APP_ENV=prod` required |
| Bucket defaulting | Based on TEST_ENV | Based on `APP_ENV` (test->test-bucket) |
| MJPEG default | Proxy URL | Will change to Pi stream (maintain env override) |
| Assertions | None | Debug-only `assertConfigured()` |
| Getter naming | mqttHost etc. | Unchanged (compat) |

### Risks If Left As-Is
1. Shipping `.env.test` in production build silently overrides `.env`.
2. Mixed test credentials in `.env` blur security boundaries.
3. Harder to reason about which environment a crash log belonged to.
4. Potential false-positive test stability if pointing at production Influx via `.env.test` default override.

### Immediate Mitigations (Pre-Refactor) – Optional
- Add a CI warning if production build command omits `--dart-define=APP_ENV=prod`.
- Add temporary log in current `Env.init()` printing: loaded file + inference reason.

This snapshot will guide validation after implementing sub-task 1.6.
