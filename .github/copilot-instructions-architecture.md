---
applyTo: "**"
---

# Repository Instructions for GitHub Copilot — Hydroponic Monitor App (Flutter)

## Project Goal
Build a **cross-platform Flutter** application (Windows, Web, Android, iOS) to **monitor and control hydroponic systems** with:
- **Real-time dashboard** (water height, humidity, temperature, pH, electricity usage)
- **Device controls** (one pump, multiple fans, lighting)
- **Video feed** (live MJPEG stream from Raspberry Pi; recording support)
- **Historical charts** (trends/analytics powered by InfluxDB)
- **System alerts** (automated rules + notifications)
- **MQTT** for sensor ingest and (optionally) device control

When in doubt, **use official Flutter docs and APIs** and prefer first-party guidance. (Reference: https://docs.flutter.dev/)

## Architecture & State
- **State management:** Use **Riverpod (hooks_riverpod)** for app-wide state and DI.
- **Layering:**
  - `lib/core/` — shared utilities (errors, result types, theming, logging).
  - `lib/features/<feature>/` — feature-first structure. Each feature contains:
    - `data/` (clients, DTOs, repositories),
    - `domain/` (entities, use cases),
    - `presentation/` (widgets, screens, controllers/providers).
- **Navigation:** `go_router`.
- **Reactivity:** Streams for live sensor/MQTT updates; providers expose stream-backed state.
- **Platform integration:** Prefer pure Dart packages. If a capability is missing, design a **thin Platform Channel** per feature.

## Data & Integrations
- **MQTT:** Use `mqtt_client` package. Connect using TLS when available. Reconnect with backoff. Topics are namespaced:  
  `hydro/<site>/<system>/<sensor|device>/<id>`
- **InfluxDB:** Use `influxdb_client` (Dart) for queries (v2, Flux). All writes happen server-side (gateway or edge) when possible; the app **reads/query-only** by default. Queries are encapsulated in repositories.
- **Video (MJPEG):** Use `flutter_mjpeg` (or a lightweight custom widget) to render streams. Expose stream URL via secure config.
- **Charts:** Use `fl_chart` for time-series (line/area). Large datasets: downsample on the query side.

## Configuration & Secrets
- Use **`--dart-define`** for runtime configuration. Provide `dart_defines.example.json` in the repo with keys:
  - `MQTT_BROKER_URL`, `MQTT_USERNAME`, `MQTT_PASSWORD`
  - `INFLUX_URL`, `INFLUX_TOKEN`, `INFLUX_ORG`, `INFLUX_BUCKET`
  - `MJPEG_URL`
- Never commit real secrets. Tests may read from a local `.env` file via `flutter_dotenv` only in dev/test builds.

## Coding Standards
- **Dart/Flutter style:** Follow `flutter_lints`. Always run `dart format`.
- **Naming:** Files `snake_case.dart`; classes `PascalCase`; providers end with `Provider`, states end with `State`.
- **Widgets:** Favor small, pure widgets; keep build methods < 100 lines. Extract styling to theme/extensions.
- **Error handling:** Never throw raw exceptions across layers. Use `Result<T, Failure>` (sealed classes) or typed errors.
- **Null safety:** No `!` unless justified in a short comment.
- **Async:** Prefer `Stream` for live updates; cancel subscriptions in `dispose`.
- **Accessibility:** Ensure semantics, contrast, scalable text, and focus traversal on desktop/web.

## UI/UX Guidelines
- Clean, modern, and legible:
  - App-wide **dark & light themes**, responsive layouts, and platform-adaptive scrolling.
  - Dashboard: **at-a-glance cards** for each sensor; trend sparklines; device toggles with clear states.
  - Controls: distinct **safety affordances** (confirmations for pump/lighting).
  - Charts screen: time range presets (1h/6h/24h/7d/30d) + pinch/drag on mobile.
  - Video: show **latency indicator** and reconnect UI.
- Follow Flutter’s official guidance where applicable (widgets, navigation, performance best practices). (See: https://docs.flutter.dev/)

## Testing & Quality
- **Unit:** providers, repositories, and use cases.
- **Widget tests:** key screens (Dashboard, Controls, Charts).
- **Golden tests:** critical widgets/states in light/dark.
- **CI expectations:** `flutter analyze`, `dart test`, build dry-runs for web and Windows at minimum.

## Telemetry & Logging
- Use structured logging (tag by feature). Redact secrets. In dev, log MQTT topic + payload sizes only.

## Commit & PR Conventions
- **Conventional Commits** (`feat:`, `fix:`, `chore:`, `docs:`, `test:`).
- Keep PRs small, focused, and accompanied by tests and screenshot/gif of UI where relevant.

## Package Suggestions (Guidance, not hard requirements)
- State/DI: `hooks_riverpod`
- Routing: `go_router`
- MQTT: `mqtt_client`
- Charts: `fl_chart`
- InfluxDB: `influxdb_client`
- MJPEG: `flutter_mjpeg`
- Env (dev/test): `flutter_dotenv`
