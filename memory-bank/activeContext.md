# Active Context - Hydroponic Monitor

> **Current work focus, recent changes, next steps, and active decisions.**

## Current Development Status

### Recent Milestones
**Real-Time Sensor Data Integration (TASK004)** ✅ *(Completed: Sept 24, 2025)*
- Live MQTT-driven dashboard operational with provider-driven streams
- Broad automated test coverage across repositories, providers, and widgets

**Actuator Control Foundation (TASK005)** ✅ *(Completed core: Sept 25, 2025)*
- DeviceControlsNotifier orchestrates command publish, pending timeouts, node gating
- Devices page groups actuators by node with status badges and emergency stop
- Provider tests cover command flow, pending → confirmed/timeout transitions
- Remaining enhancements tracked (payload enrichment, LWT node health, integration tests)

**Web MJPEG Streaming Support (TASK007)** ✅ *(Completed: Sept 25, 2025)*
- Unified phase model: idle → connecting → waitingFirstFrame → playing → error
- Web-compatible fetch-based controller with JPEG boundary parsing + resolution events
- 5s connection timeout prevents long hangs; clear error surfaced in UI
- Simulation mode badge clarifies feature-flagged runs; widget tests updated

### Current Development Focus: **Manual Reconnect & Historical Data Spike** 🎯
*Status: In Planning (September 26, 2025)*
- TASK008 manual reconnect: design `ConnectionRecoveryService` for MQTT + Influx retries
- Validate dashboard Refresh UX (progress indicator + snackbar outcomes)
- Historical charts spike: evaluate fl_chart, finalize Influx query windows & caching strategy

### Upcoming: **Historical Data Integration (TASK - TBD)** 📊
*Status: Queued (September 2025)*
- Implement chart rendering (line charts with fl_chart) fed by Influx queries
- Provide time range controls (1h, 24h, 7d, 30d) + aggregation mode toggles
- Merge historical metrics alongside live dashboard tiles

## Active Work Items

#### 1. Actuator Control Enhancements (TASK005 follow-ups)
**Priority**: Medium  
**Status**: Refinement  
**ETA**: October 02, 2025

**Remaining Tasks**:
- [ ] Enrich command payload schema (deviceNode/deviceType/parameters envelope/requestID)
- [ ] Incorporate MQTT LWT for node offline detection + smoothing
- [ ] Add integration coverage for publish/ack payload round trip
- [ ] Document final schema + node gating rules in systemPatterns.md

**Success Criteria**:
- Command payloads align with broker contract and include metadata for observability
- Node-level offline detection drives UI disable states without false positives
- Integration tests validate `grow/{node}/actuator/set` + status echo
- Documentation updated to capture finalized control flow

#### 2. Manual Reconnect Workflow (TASK008)
User-requested enhancement: dashboard Refresh should tear down and reinitialize MQTT & InfluxDB with explicit success/partial/failure messaging. Task spec documented (`TASK008-dashboard-refresh-reconnect.md`); awaiting implementation kickoff.

### Immediate Next Steps (Next 7 Days)

#### 1. Manual Reconnect Service Spike
- Draft `ConnectionRecoveryService` API + provider wiring
- UX spec for dashboard Refresh (loading indicator + snackbar states)
- Add structured logging for attempts

#### 2. Historical Charts Prototype
- Validate fl_chart with sample data (line chart + tooltip interactions)
- Prototype repository method for time-ranged Influx queries with fallback
- Determine caching/aggregation rules per range

#### 3. Actuator Control Polish
- Finalize payload metadata schema + broker documentation
- Add provider-level integration smoke test harness (using mocks/fake MQTT)
- Update systemPatterns.md with finalized control flow diagrams

## Development Workflow Status

### Active Development Patterns
- **Clean Architecture**: Fully implemented across all features
- **Test-Driven Development**: 78+ unit tests, 11+ integration tests maintaining high coverage
- **Real-Time Integration**: Complete MQTT → Provider → UI data flow functional and tested
- **CI/CD Integration**: Automated testing, formatting, and deployment pipeline active
- **Documentation-First**: All features documented in Memory Bank before implementation

### Decision Log

#### Decision A-001: Memory Bank Documentation Structure
**Date**: September 6, 2025  
**Status**: Complete  
**Context**: Need session-independent project continuity system  
**Decision**: Implement hierarchical documentation with mermaid diagrams  
**Alternatives Considered**: Wiki system, embedded code comments, external tools  
**Rationale**: Self-contained, version-controlled, easily maintainable  
**Outcome**: Successfully implemented and actively maintained

#### Decision A-002: Real-Time Data Integration Architecture  
**Date**: September 24, 2025  
**Status**: Complete  
**Context**: Dashboard needs live sensor updates from MQTT streams  
**Decision**: Use Riverpod provider architecture with reactive data flow  
**Alternatives Considered**: Manual polling, WebSocket alternative, direct widget subscriptions  
**Rationale**: Leverages existing architecture, provides clean separation of concerns, excellent testability  
**Outcome**: Complete implementation with 78+ tests passing, all real-time functionality verified

#### Decision A-003: Historical Data Visualization Priority
**Date**: September 24, 2025  
**Status**: Active Planning  
**Context**: Need time-series charts for sensor analytics and trend analysis  
**Decision**: Implement fl_chart with InfluxDB integration as next development priority  
**Alternatives Considered**: External charting service, custom chart implementation  
**Rationale**: fl_chart provides native Flutter performance, InfluxDB optimized for time-series data  
**Expected Outcome**: Rich historical data visualization with customizable time ranges

## Related Documents
- **← Project Brief**: [projectbrief.md](./projectbrief.md) - Foundation project scope
- **← Product Context**: [productContext.md](./productContext.md) - User experience goals
- **← System Patterns**: [systemPatterns.md](./systemPatterns.md) - Architecture patterns  
- **← Tech Context**: [techContext.md](./techContext.md) - Technology implementation
- **← Testing Procedure**: [testing-procedure.md](./testing-procedure.md) - Complete testing guide
- **→ Progress**: [progress.md](./progress.md) - Current status and roadmap
- **→ Tasks**: [tasks/](./tasks/) - Individual work items and tracking

---

*Last Updated: 2025-09-25*