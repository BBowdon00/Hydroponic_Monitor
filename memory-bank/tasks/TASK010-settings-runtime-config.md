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
3. Reconstruct or reinitialize MQTT, Influx, and video subsystems when settings are saved with a manual button, leveraging the manual reconnect workflow. Try to reuse code where possible.
4. Update the Settings UI to load current values, validate input, and provide clear success/error feedback.
5. Cover configuration edge cases with targeted tests (repository, providers, widget flows).

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
