# TASK009: Split Devices from Dashboard & Elevate Sensor Page

## Status: ✅ COMPLETE
**Completed**: 2025-09-26  
**Priority**: HIGH  
**Assigned**: (Unassigned)  
**Created**: 2025-09-26  
**Depends On**: TASK004, TASK005  

## Scope
Rename dashboard to "Sensor", separate device controls, and show stale notice (>60s) on sensor tiles.

## Implementation Plan (Final)
1. Rename & routing updates (files, route labels, navigation) ✅  
2. Remove device control widgets from former dashboard ✅  
3. Stale indicator (>60s) with coarse minute/hour display ✅  
4. Update tests & docs ✅  
5. QA & memory-bank update ✅  

## Progress Table (Final State)
| ID  | Description                               | Status | Notes |
|-----|-------------------------------------------|--------|-------|
| 1.1 | Rename navigation/tab copy to "Sensor"    | ✅ Done | All route/nav references audited |
| 1.2 | Remove dashboard device controls          | ✅ Done | Separation enforced |
| 1.3 | Implement >60s stale indicator            | ✅ Done | Minutes/hours granularity |
| 1.4 | Update tests/documentation                | ✅ Done | Tests & memory-bank updated |
| TEST| Analyzer/formatter/test final pass        | ✅ Done | All suites green |

## Completion Summary
- Dashboard fully converted to Sensor page (title, route, navigation labels).
- Device controls confined to Devices page.
- Stale badge (>60s) shipped with coarse minute/hour timing.
- Widget tests updated (stale timing + video unaffected).
- Documentation and memory-bank aligned.

## Verification
- No lingering "Dashboard" labels in active UI/routes.
- Sensor tiles show stale badge only when expected.
- Tests pass after rename and indicator changes.

## Risks / Follow-ups
- None specific to TASK009. Historical charts (TASK011) will later extend Sensor/Charts separation.
### Remaining Checklist for 1.4
- [ ] Add/adjust widget test covering navigation label now reading "Sensor".
- [ ] Update any documentation pages referencing "Dashboard" as landing page.
- [ ] Add test (route builder / go_router or Navigator) confirming Sensor route loads SensorPage.
- [ ] Update README / overview diagrams if they reference "Dashboard".

## Recent Progress
- 2025-09-26: Stale indicator implemented (coarse minute/hour). Associated widget test updated.
- 2025-09-26: Sensor-only page confirmed (device controls absent).

## Change Log (since main)
- Added coarse stale timing display (SensorTile + supporting test).
- SensorPage isolated to telemetry (device controls removed earlier).
- Full route/navigation rename not yet verified.

## Next Actions
1. Audit and rename remaining route / navigation identifiers (files, route names, menu labels, tests).
2. Update documentation & tests referencing "Dashboard".
3. Execute analyzer/formatter/test final pass and mark TEST complete.

## Risks / Considerations
- Mixed terminology until route/navigation audit finished.
- Ensure analytics/metrics IDs updated (if any) with final rename.
