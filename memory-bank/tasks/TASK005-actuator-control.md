# TASK005: Actuator Control System with Node Grouping and Status

## Status: IN PROGRESS

Priority: HIGH
Assigned: GitHub Copilot
Created: 2025-09-24

## Original Request
Implement an actuator control system that allows sending commands via MQTT, verifies actuator state via status feedback, and organizes actuator controls in the device tab grouped by controlling node. Each node should display an online/offline status indicator. Additionally, prepare a testing framework for actuator state management.

## Goals & Acceptance Criteria

- MQTT Commands: Functions exist to send actuator control commands (on/off, parameters) to nodes (rpi, esp1, esp2) using topic pattern `grow/{node}/actuator/set`. Current payload includes: deviceID, command, (flattened) parameters, timestamp. Follow-up: add deviceNode, deviceType, parameters envelope, requestID, reason.
- Node Status Display: Devices page groups actuators by node (rpi, esp1, esp2) and shows a status badge per node (Online/Offline/Pending/Error), derived from most recent device/actuator updates for that node (LWT-ready). Controls are disabled when node is Offline or Error.
- Testing Framework: Unit/provider tests exist for command flow, state transitions (online/offline/pending/error), and node status aggregation. Integration scaffolding prepared for MQTT-driven flows.

## Architecture Overview

Contract
- Input: UI actions (toggle, intensity), target deviceId formatted as `{node}_{type}_{id}`
- Output: MQTT command published, provider state reflects Pending -> Confirmed/Error
- Error modes: MQTT disconnected, malformed payload, command timeout, node offline
- Success: Command acknowledged via status message parsed into Device entity and applied to UI

Key Data Flows
1) UI -> DeviceControlsNotifier -> DeviceRepository.controlDevice -> MqttService.publishDeviceCommand -> MQTT Broker
2) MQTT Broker -> MqttService -> DeviceRepository/MQTT stream -> Providers -> UI

Topics
- Commands publish: `grow/{node}/actuator/set`
- Status subscribe: `grow/+/actuator`, `grow/+/device`

## Implementation Plan

1. Data/API Design
- Confirm deviceId convention `{node}_{type}_{id}`
- Payload schema for commands as listed above
- Map MQTT status payloads to `Device` domain entity (type, id, running -> status/isEnabled)

2. Data Layer
- Ensure MqttService exposes publishDeviceCommand(deviceId, command, {parameters}) and is connected before publish [Done]
- DeviceRepository delegates controlDevice/turnOn/turnOff to MqttService, exposes deviceStatusUpdates stream [Done]
- Follow-up: align command payload schema (deviceNode, deviceType, parameters envelope, requestID, reason)

3. Providers
- DeviceControlsNotifier: track `isPending` per device with commandId and 10s timeout; update state on Device status; expose grouping by node [Done]
- Node status provider: compute node status from devices under that node [Done]
- Safety: Guard controlDevice() to avoid sending commands when node is not Online [Done]
- Test hooks: disable timeouts and node-online enforcement in tests to avoid hangs/cycles [Done]

4. UI
- Devices page sections per node (rpi, esp1, esp2) with status badge; list DeviceCards under each [Done]
- Emergency Stop section surfaced at top for deterministic widget tests [Done]
- Disable device toggles/sliders when node is Offline/Error and show inline notice [Done]

5. Testing
- Unit: provider pending -> confirmed -> timeout transitions; node status aggregation [Done]
- Mock/MQTT stub: publishDeviceCommand success/failure; simulate incoming status [Done]
- Widget: Devices page emergency stop, layout, badges [Done]
- Integration scaffolding: topic/payload conformance using TestMqttPayloads [Planned]

## Subtasks & Tracking

| ID | Description | Owner | Status |
|----|-------------|-------|--------|
| 1.1 | Define command payload schema and topic usage | Copilot | Complete |
| 2.1 | Validate MqttService.publishDeviceCommand API | Copilot | Complete |
| 2.2 | Ensure DeviceRepository exposes deviceStatusUpdates and control methods | Copilot | Complete |
| 2.3 | Align publish payload: deviceNode/deviceType/parameters envelope/requestID/reason | Copilot | Planned |
| 3.1 | DeviceControlsNotifier pending/timeout handling | Copilot | Complete |
| 3.2 | Providers: devicesByNode, nodeStatusProvider | Copilot | Complete |
| 3.3 | Safety & test hooks (node-online enforcement, timeout toggles) | Copilot | Complete |
| 4.1 | DevicesPage grouped by node with badges | Copilot | Complete |
| 4.2 | Disable controls when node Offline/Error + inline notice | Copilot | Complete |
| 5.1 | Unit/provider tests for control + node status | Copilot | Complete |
| 5.2 | Integration tests for publish/receive payloads | Copilot | Planned |

## Current Implementation Summary (2025-09-24)

- MQTT command publishing wired via `MqttService.publishDeviceCommand` (deviceID, command, params, timestamp)
- Live device status consumed and reflected by `DeviceControlsNotifier`; dynamic device discovery from MQTT messages
- Devices grouped by node with node-level status badges; Emergency Stop section stable for tests
- Controls disabled when node Offline/Error (provider guard + UI disabled state)
- Tests: All presentation tests passing locally; provider tests stabilized (timeouts and circular deps avoided with test hooks)

## Remaining Work

- Enrich command payload schema: deviceNode, deviceType, parameters envelope, requestID, reason
- Add MQTT LWT-based node offline detection and status smoothing where applicable
- Add integration tests (end-to-end publish/receive payload conformance)
- Documentation: update systemPatterns.md with finalized actuator command schema and node disable rules

## Risks & Mitigations

- MQTT Disconnects: Detect via connection stream; disable publish when disconnected; surface Pending/Error states
- Out-of-order Messages: Use lastUpdate timestamps; last-write-wins in provider
- Node Offline Detection: Prefer MQTT LWT; fallback heuristic via recent device messages
- WebSockets vs TCP: Use Browser client on web with ws://host:9001 and server client elsewhere

## Test Plan

- Follow memory-bank/testing-procedure.md for running unit, widget, and integration tests
- Add tests to `test/presentation/providers/*` for provider logic and to `test/data/mqtt/*` for command publishing behavior
- Verify topic and payload through mocks and string assertions

## Done When
- Commands can be published for devices on rpi, esp1, esp2
- UI groups devices by node with node status badge
- Device states reflect confirmations or timeouts
- Tests present for command flow and node status
- Controls are disabled when node is Offline/Error
- Tests present and passing for command flow and node status

## Links
- System Patterns: memory-bank/systemPatterns.md (Actuator Control Flow)
- Tech Context: memory-bank/techContext.md (MQTT details)
- Testing Procedure: memory-bank/testing-procedure.md

---

Last Updated: 2025-09-24
