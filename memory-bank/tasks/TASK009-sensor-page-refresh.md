# TASK009: Split Devices from Dashboard & Elevate Sensor Page

## Status: ⏳ REQUESTED

**Priority**: HIGH  
**Assigned**: (Unassigned)  
**Started**: —  
**Created**: 2025-09-26  
**Depends On**: TASK004 (Real-time sensor streaming), TASK005 (Actuator control foundation)  
**Related**: `lib/presentation/pages/dashboard_page.dart`, `lib/presentation/pages/devices_page.dart`, `lib/presentation/routes.dart`

## Original Request
Remove device controls from the dashboard, rename that page to "Sensor," and display a notice on each sensor tile when its data is more than one minute old.

## Thought Process
1. The landing page should highlight live telemetry only; actuator toggles already live in the Devices tab.  
2. Renaming navigation and routes keeps terminology consistent with the page’s purpose.  
3. A stale indicator prevents growers from trusting outdated readings when connectivity hiccups occur.

## Implementation Plan
1. **Rename & Routing** – Update `DashboardPage` artifacts (class/file, routes, navigation labels) to "Sensor".
2. **Remove Device Controls** – Delete the dashboard device control section; ensure Devices page remains authoritative.
3. **Stale Indicator** – Add helper to flag readings older than 60 seconds and surface an inline badge/message on each tile.
4. **Copy & Tests** – Refresh strings/docs/tests referencing "Dashboard"; extend widget/unit coverage for stale logic.
5. **QA & Docs** – Run formatter/analyzer/tests and update memory-bank entries post-implementation.

## Progress Tracking
| ID | Description | Status | Notes |
|----|-------------|--------|-------|
| 1.1 | Rename navigation/tab copy to "Sensor" | ☐ Not Started | Update routes, shell labels, analytics IDs |
| 1.2 | Remove dashboard device control widgets | ☐ Not Started | Ensure Devices page still exposes toggles |
| 1.3 | Implement >60s stale indicator on sensor tiles | ☐ Not Started | Include elapsed time tooltip/copy |
| 1.4 | Update tests/documentation | ☐ Not Started | Widget + unit coverage for stale logic |
| TEST | Test run (formatter/analyzer/tests) | ☐ Not Started | Follow `testing-procedure.md` |

## Progress Log
### [2025-09-26]
- 📝 Task scoped; awaiting development kickoff.

> **VERIFICATION PENDING**: No code changes yet; implementation will proceed per plan above.
