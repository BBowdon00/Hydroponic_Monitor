# Active Context

## High-Level Summary
- Runtime configuration (TASK010) implemented: settings persistence, dynamic MQTT/Influx rebuild with retire pattern, idle-safe HLS URL updates.
- HLS video streaming migration complete: H.264 streaming via video_player (mobile/desktop) and iframe embedding (web), fullscreen mode with immersive UI.
- Sensor page refactor (TASK009) complete (naming, stale badge, separated controls).

## Recently Completed
- TASK010: Dynamic settings (AppConfig + ConfigRepository + staged Apply), provider invalidation + manual reconnect integration, added tests.
- VideoState stabilization (no rebuild churn on config load; user-modified URL protection).

## Open Follow-Ups
- Manual reconnect UX polish & metrics (TASK008 refinement).
- Historical charts (TASK011).
- Production readiness hardening (TASK012) – remove dummy Influx fallbacks.
- Config diff banner & batch apply (future TASK010 enhancement).

## Testing
- All suites passing: added config persistence tests, dynamic reconfiguration integration, recreated video_page_test.dart for HLS streaming with comprehensive widget tests.