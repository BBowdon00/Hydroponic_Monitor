# TASK010: Settings-Driven Runtime Configuration

Status: REQUESTED
Priority: High
Created: 2025-09-26
Owner: (Unassigned)
Depends On: TASK004 (Real-time data pipeline), TASK005 (Actuator control foundation), TASK007 (MJPEG streaming state model), upcoming TASK008 (manual reconnect service)
Related: `lib/presentation/pages/settings_page.dart`, `lib/core/env.dart`, `lib/presentation/providers/data_providers.dart`, `lib/presentation/pages/video_page.dart`, `lib/core/video/mjpeg_stream_controller.dart`

## Motivation
The Settings page currently presents static placeholders for MQTT, InfluxDB, and MJPEG configuration. Operators expect those controls to persist updates and adjust the live services without restarting the app. A functional settings flow also unlocks per-deployment customization, secure credential storage, and proactive recovery tooling that pairs well with the planned manual reconnect banner.

## Current Behavior & Constraints
- `SettingsPage` hardcodes example values and only shows dialogs without storing results.
- `Env` exposes static getters backed by `.env` or process variables; values are read during provider construction and never updated at runtime.
- `mqttServiceProvider` and `influxServiceProvider` instantiate services directly from `Env`, so changes require app restart.
- `VideoStateNotifier` seeds the MJPEG URL with a constant string and does not coordinate with settings.
- Sensitive credentials (MQTT password, Influx token) should not live in plain text storage; the app already depends on `flutter_secure_storage`.
- Manual reconnect (TASK008) will soon orchestrate connection resets, so settings updates should trigger similar flows instead of duplicating logic.

## Problem Statement
Users cannot adjust broker, database, or stream endpoints on the fly. Without persistence and runtime reconfiguration, the Settings page fails its core purpose, leading to brittle deployments and manual restarts whenever infrastructure changes.

## Objectives
1. Persist MQTT, InfluxDB, and MJPEG configuration with secure handling for secrets.
2. Expose a typed runtime configuration model that surfaces defaults from `Env` but supports user overrides.
3. Reconstruct or reinitialize MQTT, Influx, and video subsystems when settings change, leveraging the upcoming manual reconnect workflow.
4. Update the Settings UI to load current values, validate input, and provide clear success/error feedback.
5. Cover configuration edge cases with targeted tests (repository, providers, widget flows).

## Proposed Approach
### Phase 1 – Config Domain & Persistence
- Define immutable models: `AppConfig`, `MqttConfig`, `InfluxConfig`, `VideoConfig`, plus copy/merge helpers.
- Implement `ConfigRepository` that:
  - Loads defaults from `Env` on first run.
  - Persists non-secret fields with `shared_preferences` (add dependency) and sensitive fields with `flutter_secure_storage`.
  - Emits a `Stream<AppConfig>` for consumers.
  - Supports clearing overrides, versioning keys, and migration guardrails.
- Provide mockable interfaces for unit testing without touching platform channels.

### Phase 2 – Runtime Apply & Service Wiring
- Add a `ConfigController` (`AutoDisposeAsyncNotifier<AppConfig>` or equivalent) in `presentation/providers` that coordinates repository I/O and exposes mutation methods.
- Update `mqttServiceProvider` and `influxServiceProvider` to `Provider.autoDispose` or `NotifierProvider` variants that watch `configController`. On config change:
  - Dispose the previous client (`disconnect()` for MQTT) before constructing a new instance.
  - Initiate reconnect via `ConnectionRecoveryService` (once TASK008 lands) or local reconnect helper during this task.
- Refactor `videoStateProvider` to seed URL from config and respond to updates (e.g., `ConfigController` pushes new URL, controller disconnects/reconnects when necessary).
- Ensure configuration updates debounce rapid changes and surface errors (connection failures, invalid host) through the controller state.

### Phase 3 – Settings UI & UX Enhancements
- Replace placeholder dialogs with forms bound to `ConfigController` state (use `Form` + `TextEditingController` per field with validation).
- Split secrets into dedicated dialogs/secure fields (mask passwords/tokens, provide "Test" actions for MQTT/Influx).
- Add optimistic loading states, success snackbars, and inline error messaging, aligning visuals with Material 3 styling.
- Provide `Restore Defaults` action that clears overrides and reverts to `.env` values, prompting confirmation.
- Hook "Test MQTT" / "Test InfluxDB" buttons to call controller test methods that reuse repository/service logic without permanently mutating state.

### Phase 4 – Testing, Telemetry, & Docs
- Unit tests: `ConfigRepository` persistence, `ConfigController` validation + mutation paths, MQTT/Influx provider rebuild behavior.
- Widget tests: Settings form loads persisted values, validation errors displayed, save triggers success feedback.
- Integration (optional stretch): simulate settings change to verify MQTT service reconnects (using test doubles/fakes).
- Emit structured logs for configuration changes (redact secrets) to aid diagnostics.
- Update memory bank (system patterns, tech context) once implementation lands.

## Edge Cases & Considerations
| Scenario | Handling |
|----------|----------|
| Invalid host/port | Validate before applying; surface inline error; do not persist until corrected. |
| Partial failures on apply | Roll back persisted change and show toast/snackbar describing failed component (MQTT vs Influx vs Video). |
| Secrets left blank intentionally | Treat blank as "clear override"; fall back to `.env` values. |
| Multi-tab config updates | Config controller emits stream updates so other screens (video page) react immediately without duplicate dialogs. |
| Platform support (web vs mobile) | Ensure repository gracefully no-ops secure storage on web (e.g., use conditional imports or fallback memory store). |

## Deliverables
- Config domain models + repository with secure storage abstraction.
- Riverpod controller + updated service providers enabling runtime reconfiguration.
- Refactored Settings page UI with validation, persistence, and feedback.
- Updated video state initialization tied to config.
- Tests (unit/provider/widget) covering new flows.
- Documentation updates post-implementation (separate task/PR).

## Testing Strategy
- Mock storage adapters to assert load/save behavior.
- Use `ProviderContainer` tests to verify service providers rebuild and call `disconnect()` on old instances.
- Widget test ensures user edits propagate to controller, validations trigger, and success snackbar appears.
- Optional: contract test verifying MQTT reconnect invoked with new host (using fake `MqttService`).

## Dependencies & Follow-ups
- Introduce `shared_preferences` dependency (verify license compliance) for non-secret persistence.
- Coordinate with TASK008 so manual reconnect utilities can be reused; if not merged yet, implement an internal helper that can be swapped later.
- Schedule doc updates in `systemPatterns.md` and `techContext.md` after implementation.

## Definition of Done
- Settings page persists and reloads configuration across app restarts.
- Applying changes updates MQTT/Influx services and MJPEG stream without restarting the app.
- Secrets stored securely; no plaintext secrets in logs or local prefs.
- Automated tests cover repository/controller/widget flows.
- No analyzer warnings; all tests (unit + widget) pass per testing procedure.
