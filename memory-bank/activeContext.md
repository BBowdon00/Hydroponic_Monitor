# Active Context - Hydroponic Monitor

> **Current work focus, recent changes, next steps, and active decisions.**

## Current Development Status

### Recent Milestones
**Real-Time Sensor Data Integration Complete (TASK004)** ✅ *(Completed: Sept 24, 2025)*
- Live MQTT-driven dashboard operational with comprehensive tests
- 78+ unit tests, 11 integration tests, 3 widget tests, 4 error handling tests passing

**Web MJPEG Streaming Support (TASK007)** ✅ *(Completed: Sept 25, 2025)*
- Unified phase model: idle → connecting → waitingFirstFrame → playing → error
- Web-compatible streaming path implemented with fetch-based controller
- 5s connection timeout prevents long hangs; clear error surfaced
- Simulation mode clearly labeled (no misleading placeholders)
- Updated widget tests reflecting new phases; disposal safety (`shutdown()`) pattern added

### Current Development Focus: **Historical Data Integration (Charts) Preparation** 🎯
*Status: In Planning (September 25, 2025)*
- Designing time-series chart architecture (fl_chart evaluation)
- Defining InfluxDB query patterns (range + aggregation)
- Identifying caching and sampling strategies for performance

### Upcoming: **Historical Data Integration (TASK - TBD)** 📊
*Status: Queued (September 2025)*
- InfluxDB historical data charts (1h, 24h, 7d, 30d)
- Aggregation & downsampling strategy
- Combine real-time + historical perspectives in unified dashboard

## Active Work Items

#### 1. Actuator Control Implementation
**Priority**: High  
**Status**: Active  
**Estimated Completion**: October 02, 2025

**Planned Tasks**:
- [ ] Implement data layer for actuators (MQTT publish/subscribe, LWT readiness)
- [ ] Add providers: command pending/timeout handling, devices-by-node, node status
- [ ] Update Devices UI: group by node, status badges, control cards
- [ ] Testing: unit/provider tests for command/state transitions and node status
- [ ] Documentation updates (systemPatterns.md)

**Acceptance Criteria**:
- Commands publish successfully for rpi, esp1, esp2 via `grow/{node}/actuator/set`
- UI reflects confirmed state changes and timeouts
- Devices grouped by node with Online/Offline badges
- Tests cover command flow and node status aggregation

#### 2. Manual Reconnect Feature Request (TASK008 - Pending)
User-requested enhancement: dashboard Refresh button should perform a manual reconnection attempt for both MQTT and InfluxDB (teardown + re-init + health check) with clear success/partial/failure feedback. Task document added (`TASK008-dashboard-refresh-reconnect.md`) and indexed under Pending.

### Immediate Next Steps (Next 7 Days)

#### 1. Historical Data Architecture Spike
- Evaluate fl_chart capabilities for large time ranges
- Draft repository + provider interfaces for historical queries
- Define query batching & cache invalidation rules

#### 2. Documentation & Memory Sync
- Update progress and system patterns with streaming architecture changes
- Add README section for enabling real MJPEG on web

#### 3. Prepare Historical Data Foundation
- Early design for chart architecture (fl_chart evaluation)
- Identify InfluxDB query patterns & indexes

#### 4. Actuator Control (Preliminary Research)
- Map required MQTT command topics & acknowledgment patterns
- Draft provisional provider interfaces (deferred implementation)

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