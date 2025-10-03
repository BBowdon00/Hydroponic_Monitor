# TASK011: Implement Sensor Charts Page & Time Range Controls

## Status: ⏳ REQUESTED

**Priority**: HIGH  
**Assigned**: (Unassigned)  
**Created**: 2025-09-26  
**Depends On**: TASK004 (Real-time streaming foundation), TASK008 (Reconnect service hooks), TASK009 (Sensor-focused dashboard copy), TASK010 (Runtime config refresh)  
**Related**: `lib/presentation/pages/charts_page.dart`, `lib/presentation/widgets/sensor_tile.dart`, `lib/presentation/providers/data_providers.dart`, `lib/data/influx/influx_service.dart`, `lib/data/repos/sensor_repository.dart`, `lib/presentation/providers/config_provider.dart`

## Original Request
Plan how to deliver a fully functional Charts page where each sensor tile (or dedicated chart card) renders a representative `fl_chart` line graph backed by InfluxDB queries. Users must be able to switch between 1h, 24h, 7d, and (existing enum already includes) 30d windows, with data fetched per sensor type.

## Implementation Plan (Refined)
The current codebase already provides: (a) `ChartRange` enum (includes 30d), (b) `chartRangeProvider`, (c) historical single-type fetch via `sensorTypeHistoryProvider`, (d) dummy fallback generation in `InfluxDbService`, and (e) runtime config-driven service rebuilds. The plan layers incremental capabilities while preserving existing provider patterns and retirement semantics.

1. **Time Series Query Abstraction**  
   - Add `queryTimeSeries(SensorType type, ChartRange range)` to `InfluxDbService` building a Flux query with `aggregateWindow(fn: mean)` and `sort()` ascending.  
   - Window sizing guideline (`range → every`): 1h→5m, 24h→1h, 7d→3h, 30d→12h. Keep <= ~180 points to avoid UI jank.  
   - Return a new `TimeSeriesPoint` model: `{DateTime ts, double value}`. Reuse dummy generator (introduce deterministic step for reproducibility in tests, seeding with sensorType hash + range).  
   - Ensure health check side effects (connection status emission) remain consistent; do not mark connected on query failure.

2. **Repository Layer Extension**  
   - Add `getSensorTimeSeries(SensorType, ChartRange)` delegating to service; map to ordered list (ascending).  
   - Avoid caching internally; rely on provider caching to keep logic testable.

3. **Provider Architecture**  
   - Introduce `sensorChartDataProvider = FutureProvider.family<ChartSeriesState, (SensorType, ChartRange)>` where `ChartSeriesState` holds: `points`, `stats (min/max/avg)`, `isFallback`.  
   - Add `chartDataRefreshTriggerProvider` (simple `StateProvider<int>` increment) that invalidates chart data when refresh icon tapped.  
   - Update `ChartsPage` refresh button to increment trigger; `sensorChartDataProvider` watches trigger + range + type.  
   - Keep existing `chartRangeProvider` (rename not required).  
   - Add lightweight memoization guard (optional) to skip duplicate in-flight queries per (type, range) to reduce thrash when range toggled quickly.

4. **UI Composition**  
   - Replace placeholder with responsive `GridView`/`SliverGrid` - one chart per `SensorType` (ordered by conceptual importance: temperature, humidity, pH, EC, waterLevel, lightIntensity, airQuality, powerUsage).  
   - Implement `SensorChartCard` (preferred over mutating `SensorTile` to keep dashboard tile lean).  
   - Card layout: header (icon + label + latest value), chart area (LineChart), footer stats (min/avg/max), loading & empty states, fallback badge (e.g., "Simulated") if `isFallback` true.  
   - Accessibility: provide semantic labels for chart container, ensure color choices meet contrast; consider color-blind friendly palette for line stroke.

5. **Chart Rendering Details**  
   - Use `fl_chart` LineChart with: cubic smoothing disabled initially, tooltips on long-press, axis bottom time labels (adaptive tick every Nth point), left axis dynamic range padded by ~5%.  
   - Provide placeholder shimmer while loading; error state with retry button that invalidates provider.  
   - Respect theme (surface / surfaceVariant) for background; use consistent stroke width (2) and subtle gradient fill at 15% opacity.

6. **Performance & Resilience**  
   - Hard cap max points (trim if service returns more).  
   - Defer heavy formatting (min/avg/max) to a single pass O(n).  
   - On runtime config change (service rebuild), allow natural provider invalidation; charts show loading then re-populate.  
   - Manual reconnect should trigger `emitCurrentStatus()` (already available) — optional follow-up: a global listener to refresh charts when status transitions from disconnected→connected (deferred unless needed).

7. **Testing & Verification**  
   - Unit: Flux builder correctness (assert aggregateWindow & range bounds).  
   - Unit: Dummy fallback determinism (same seed => stable first few points).  
   - Provider: range switch invalidation, refresh trigger increments, fallback flag when service uninitialized.  
   - Widget: `ChartsPage` renders expected number of chart cards; loading → data path; fallback badge visible when forcing dummy path.  
   - Integration (optional later): With real InfluxDB container seeded with sample data (future script).  
   - Analyzer & lints: zero new warnings.

8. **Documentation & Memory Bank**  
   - Update `techContext.md` Time-Series section: add time series aggregation details.  
   - Update `systemPatterns.md` adding mini note referencing chart provider pattern (points capping + fallback).  
   - Mark TASK011 progress log with incremental checkpoints.

## Acceptance Criteria
| Category | Requirement |
|----------|-------------|
| Ranges | User can select 1h, 24h, 7d, 30d; selection persists during session via `chartRangeProvider`. |
| Data Query | Each sensor type queries aggregated series with capped point count (≤ ~180). |
| Fallback | When Influx unavailable/uninitialized, dummy series returns ordered timestamps and sets `isFallback=true`. |
| UI States | Each chart card shows: loading skeleton, error (with retry), empty (graceful copy), data (line + stats). |
| Stats | Min, max, average displayed and recomputed on refresh or range change. |
| Performance | Average provider load for one range switch < 200ms with dummy data (local). |
| Runtime Config | Changing Influx config and applying invalidates charts and they refetch without crash. |
| Reconnect | Manual reconnect (TASK008) after outage allows charts to repopulate on next refresh or range toggle. |
| Testing | All new tests pass; existing suites remain green. |
| Accessibility | Chart cards have semantic labels; text contrast meets AA (manual spot check). |

## Risks & Mitigations
| Risk | Mitigation |
|------|-----------|
| Excess points degrade frame time | Enforce cap & aggregated bucket sizing table. |
| Query latency blocks UI | Use async providers; show non-blocking loading states. |
| Dummy vs real data confusion | Display subtle "Simulated" badge when `isFallback`. |
| Provider storm on rapid range toggles | Debounce or ignore in-flight duplicate per (type, range). |
| Inconsistent time ordering from backend | Always sort ascending after parse. |
| Large 30d window still heavy | Wider bucket (12h) to bound points <= 62. |
| Memory growth from caching | Rely on provider invalidation; avoid long-lived in-memory caches first iteration. |

## Implementation Sequencing (Recommended)
1. Service & model additions (TimeSeriesPoint + queryTimeSeries).  
2. Repository method + provider family scaffold.  
3. Chart card widget + integration into `ChartsPage`.  
4. Performance tuning (point cap, stats).  
5. Testing (unit → provider → widget).  
6. Docs & memory-bank updates.  

## Notes on Existing Code Utilization
- Reuse `chartRangeProvider` (already present) – extend chips to include 30d if not yet surfaced.  
- Leverage dummy generation logic in `InfluxDbService` (extend for deterministic seeding).  
- Respect runtime config providers; no direct Env lookups in new providers.  
- Avoid writing historical data (writing was removed) – focus read-only queries.

## Progress Tracking
| ID | Description | Status | Notes |
|----|-------------|--------|-------|
| 1.1 | Add `TimeSeriesPoint` model | ☐ Not Started | Value + timestamp, equality by timestamp |
| 1.2 | Implement `queryTimeSeries` in `InfluxDbService` | ☐ Not Started | aggregateWindow + point cap + fallback deterministic |
| 1.3 | Repository method `getSensorTimeSeries` | ☐ Not Started | Delegates to service, sorts ascending |
| 1.4 | `sensorChartDataProvider` family | ☐ Not Started | (SensorType, ChartRange) + refresh trigger |
| 1.5 | `SensorChartCard` widget | ☐ Not Started | LineChart + states + stats + fallback badge |
| 1.6 | Integrate cards into `ChartsPage` | ☐ Not Started | Replace placeholder grid layout |
| 1.7 | Performance guard (debounce/in-flight) | ☐ Not Started | Optional; implement if test indicates churn |
| 1.8 | Tests (unit/provider/widget) | ☐ Not Started | Query builder, dummy determinism, UI states |
| 1.9 | Documentation updates | ☐ Not Started | techContext + systemPatterns + progress markdown |

## Progress Log
### [2025-09-26]
- 📝 Initial task scoped (original version).

### [2025-10-03]
- 🔄 Plan refined to align with runtime config pattern, service retirement, enhanced Influx health + dummy generation.
- 🧩 Added acceptance criteria, risks, sequencing, and extended 30d range scope.

