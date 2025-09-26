# TASK011: Implement Sensor Charts Page & Time Range Controls

## Status: ⏳ REQUESTED

**Priority**: HIGH  
**Assigned**: (Unassigned)  
**Created**: 2025-09-26  
**Depends On**: TASK004 (Real-time streaming foundation), TASK008 (Reconnect service hooks), TASK009 (Sensor-focused dashboard copy), TASK010 (Runtime config refresh)  
**Related**: `lib/presentation/pages/charts_page.dart`, `lib/presentation/widgets/sensor_tile.dart`, `lib/presentation/providers/sensor_providers.dart`, `lib/data/influx/influx_service.dart`, `lib/data/repos/sensor_repository.dart`

## Original Request
Plan how to deliver a fully functional Charts page where each sensor tile renders a representative fl_chart line graph backed by InfluxDB queries. Users must be able to switch between 1h, 24h, and 7h windows, with data fetched per sensor type.

## Thought Process
1. Historical analytics sits on top of the existing SensorRepository + InfluxDbService stack, so we can extend those layers rather than invent new services.
2. Chart visuals should reuse Riverpod so the UI stays reactive to time-range selection and data reloads, matching the rest of the app.
3. We need to constrain point counts per range (downsampling/aggregation) so charts remain performant across platforms.
4. Sensor tiles already exist; augmenting them (or composing new chart cards) preserves design consistency while embedding fl_chart.
5. Tests must cover both fallback dummy data paths and real query formatting to keep development environments resilient.

## Implementation Plan
1. **Data Access Enhancements**  
   - Add a `queryTimeSeries` helper to `InfluxDbService` that accepts `SensorType`, optional `deviceId`, and a `ChartRange`-derived window.  
   - Use Flux `aggregateWindow` with sensible `every` values (e.g., 1h ➝ 5m, 24h ➝ 1h, 7h ➝ 15m) and ensure fallback dummy generation returns ordered points.  
   - Introduce a lightweight `TimeSeriesPoint` model (timestamp + value) if `SensorData` isn’t a perfect fit.

2. **Repository & Provider Layer**  
   - Extend `SensorRepository` with `getSensorTimeSeries(SensorType, ChartRange)` returning ordered point lists.  
   - Create Riverpod async providers (`chartRangeProvider`, `sensorChartDataProvider.family`) that cache by sensor & range, handle loading/error states, and expose refresh triggers.  
   - Wire providers to refresh when the user changes the global range chips or taps the refresh icon.

3. **UI Composition**  
   - Replace the placeholder in `ChartsPage` with a scrollable grid/list of chart cards—one per `SensorType`.  
   - For each card, show a header (icon + latest value), embedded `LineChart` from fl_chart, loading/empty states, and mini stats (min/avg/max) computed client-side.  
   - Update time-range chips to the required trio: 1h, 24h, 7h, and persist the selection via `ChartRangeNotifier`.

4. **Widget Refinements & Reuse**  
   - Option A: Extend `SensorTile` with an optional chart slot fed by the new provider.  
   - Option B: Build a `SensorChartCard` widget that encapsulates chart rendering and stats while borrowing SensorTile styling tokens.  
   - Ensure responsiveness (two-column grid on wide screens, single column on mobile) and accessible color contrast.

5. **Testing & Verification**  
   - Unit-test `InfluxDbService` query-builder to confirm Flux strings and fallback data ordering.  
   - Provider tests for cache invalidation, range switching, and refresh behavior.  
   - Widget test snapshot for `ChartsPage` verifying loading, data, and error UI states.  
   - Follow `testing-procedure.md`: formatter, analyzer, targeted provider/widget tests, and `./scripts/test-runner.sh --unit` at minimum.

## Progress Tracking
| ID | Description | Status | Notes |
|----|-------------|--------|-------|
| 1.1 | Implement `queryTimeSeries` in `InfluxDbService` | ☐ Not Started | Include aggregateWindow + fallback data |
| 1.2 | Add repository/provider plumbing for sensor time series | ☐ Not Started | Riverpod providers keyed by sensor & range |
| 1.3 | Build charts UI with fl_chart + responsive layout | ☐ Not Started | Include stats, loading, empty, error states |
| 1.4 | Embed charts per sensor tile/card with range controls | ☐ Not Started | Decide on SensorTile extension vs new widget |
| 1.5 | Testing pass & documentation updates | ☐ Not Started | Analyzer, unit/provider/widget tests, memory bank refresh |

## Progress Log
### [2025-09-26]
- 📝 Task scoped with detailed plan covering data access, providers, UI, and testing.

> **VERIFICATION PENDING**: Implementation not started; plan ready for execution.
