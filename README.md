[![CI/CD Pipeline](https://github.com/BBowdon00/Hydroponic_Monitor/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/BBowdon00/Hydroponic_Monitor/actions/workflows/ci.yml)
# Hydroponic Monitor 🌱

A cross-platform Flutter application to monitor and control hydroponic systems with real-time sensors, device controls, video feed, historical charts, and MQTT integration. The app provides an intuitive dashboard for tracking water levels, temperature, humidity, pH, and electrical conductivity while enabling remote control of pumps, fans, lighting, and heating systems.

## Features

- **Real-time Dashboard**: Monitor key sensors (water level, temperature, humidity, pH, EC, light) with live updates and trend indicators
- **Device Controls**: Remote control of water pumps, circulation fans, LED grow lights, and heaters with intensity adjustment
- **Video Feed**: Live MJPEG stream viewing from Raspberry Pi cameras with connection management
- **Historical Charts**: Time-series analytics with customizable ranges (1h, 24h, 7d, 30d) powered by InfluxDB
- **Smart Alerts**: Configurable alert rules and incident management for system monitoring
- **MQTT Integration**: Real-time data ingestion and device control via MQTT protocol
- **Settings Management**: Easy configuration for MQTT, InfluxDB, video streams, and app preferences
- **Dark/Light Themes**: Material 3 design with responsive layouts for all screen sizes

## Architecture Overview

The app follows a clean architecture pattern with feature-first organization:

```
lib/
├── core/                    # Shared utilities
│   ├── env.dart            # Environment configuration
│   ├── errors.dart         # Error handling types
│   ├── logger.dart         # Structured logging
│   └── theme.dart          # Material 3 theming
├── data/                   # Data layer
│   ├── mqtt/              # MQTT client implementation
│   ├── influx/            # InfluxDB client
│   └── repos/             # Repository implementations
├── domain/                 # Business logic
│   ├── entities/          # Domain models
│   └── usecases/          # Business operations
└── presentation/           # UI layer
    ├── app.dart           # App configuration
    ├── routes.dart        # Navigation setup
    ├── pages/             # Screen implementations
    ├── widgets/           # Reusable UI components
    └── providers/         # State management
```

### Key Technologies

- **State Management**: Riverpod (hooks_riverpod) for reactive state and dependency injection
- **Navigation**: go_router for type-safe, declarative routing
- **Data Sources**: MQTT (mqtt_client), InfluxDB (influxdb_client)
- **Charts**: fl_chart for time-series visualization
- **Storage**: flutter_secure_storage for sensitive configuration
- **Theming**: Material 3 with 8-point grid system and consistent spacing

## UI Principles

- **Material 3 Design**: Modern, accessible interface with adaptive theming
- **8-Point Grid**: Consistent spacing using multiples of 8dp for visual harmony
- **Component Library**: Reusable widgets (SensorTile, DeviceCard, StatusBadge) for maintainability
- **Responsive Layout**: Optimized for mobile, tablet, and desktop form factors
- **Accessibility**: Semantic labels, proper contrast ratios, and keyboard navigation support

## Quick Start

### Prerequisites

- Flutter SDK 3.35.2+ (Dart 3.9.0+)
- For web deployment: Modern web browser with WASM support
- For Android: Android SDK and emulator/device
### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/BBowdon00/Hydroponic_Monitor.git
   cd Hydroponic_Monitor
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure environment:**
   ```bash
   cp dart_defines.example.json dart_defines.json
   # Edit dart_defines.json with your MQTT, InfluxDB, and video stream settings
   ```
   For dev/test builds, you may use `.env` and `flutter_dotenv` as described in the architecture guide.

4. **Run the application:**
   ```bash
   # Web (recommended for development)
   flutter run -d web-server --web-port 8080
   
   # Android
   flutter run -d android
   
   # Linux desktop (if GTK3 headers installed)
   flutter run -d linux
   ```

### Development Commands

```bash
# Code quality checks
flutter analyze                              # Static analysis
dart format .                               # Code formatting

# Testing
flutter test                                # Run all tests
flutter test --coverage                     # Generate coverage report

# Building
flutter build web                           # Web production build
flutter build apk --debug                   # Android debug APK
flutter build linux                         # Linux desktop binary
```

## Developer Onboarding

**Before starting development, please read:**
- [Operational Instructions](.github/copilot-instructions.md)
- [Architecture & Coding Standards](.github/copilot-instructions-architecture.md)

These documents contain essential setup, workflow, and code style guidance.

## Environment Setup

Follow the steps in `.github/workflows/copilot-setup-steps.yml` for environment preparation.  
Ensure you have the correct Flutter/Dart versions and platform dependencies.

## Testing

To run all tests (unit + integration) locally, use the provided automation script:
```bash
./scripts/test-runner.sh --all --verbose
```
For integration test troubleshooting, check logs:
```bash
cat test/logs/*.log
```
See [Operational Instructions](.github/copilot-instructions.md) for detailed test failure analysis and resolution steps.

## References

- **Flutter Documentation**: https://docs.flutter.dev/
- **Flutter API Reference**: https://api.flutter.dev/
- **Flutter Gallery**: https://github.com/flutter/gallery (UI inspiration)
- **Flutter Samples**: https://github.com/flutter/samples
- **Material 3 Design**: https://m3.material.io/
- **Riverpod Documentation**: https://riverpod.dev/
- **Go Router Guide**: https://docs.page/csells/go_router

## Backend Infrastructure and Data 
The infrastructure behind the Hydroponic Monitor app consists of a distributed network of hardware devices, MQTT message broker, and InfluxDB time-series database that work together to provide real-time monitoring and control capabilities. The app will subscribe and wait for MQTT messages. It will update the sensor and actuator/device tiles with the latest data received. It will only interface with Influxdb for historical data and chart making. All other data comes from the MQTT subscriptions & message payloads. It will be common that this app is not connected to the servers and thus must gracefully handle disconnection states from the MQTT and influxdb services, while updating appropriately when re-connected.

### Hardware Architecture

The system is built around multiple microcontroller nodes deployed throughout the hydroponic environment:

- **Ubuntu Server**: MQTT Broker, runs influxdb, and other containers
- **Raspberry Pi devices**: Primary controllers running full Linux OS, hosting cameras for MJPEG streams and managing multiple sensors/actuators
- **ESP32 microcontrollers**: Distributed sensor nodes and actuator controllers positioned strategically around growing areas
- **Sensors**: Temperature, humidity, pH, electrical conductivity (EC), water level sensors, and total power usage sensors
- **Actuators**: Water pumps, circulation fans, LED grow lights

Each device operates independently with its own sensor/actuator management while participating in the larger network ecosystem.

### MQTT Message Broker

The MQTT broker serves as the central nervous system for real-time communication between all devices and the monitoring app. It handles four primary message types:

Topic format:
{project}/{node}/{deviceCategory}

**Sensor Data Messages** (e.g., `grow/rpi/sensor`):
```json
{
   "deviceType": "temperature",
   "deviceID": "1", 
   "location": "tent",
   "value": "23.22",
   "description": "under light"
}
```

**Actuator Status Messages** (e.g., `grow/rpi/actuator`):
```json
{
   "deviceType": "pump",
   "deviceID": "2",
   "location": "tent", 
   "running": true,
   "description": "main circulation"
}
```

**Device Health Messages** (e.g., `grow/esp32_1/device`):
```json
{
   "deviceType": "microcontroller",
   "deviceID": "1",
   "location": "tent",
   "running": false,
   "description": "esp32 board on floor"
}
```
**Actuator Action Request** (e.g. `grow/rpi_2/actuator/set`)
```json
{
   "deviceType": "fan",
   "deviceID":"3",
   "location":"tent",
   "requestID": "phone",
   "reason": "manual", // automatic, or kill switch
   "duration": "-", //duration of "-" = infinite (until turned off/on). In seconds
   "action": "on", // "on", "off", or "toggle"
}
```

### Dashboard/Display Integration for Sensor Data
Each tile will display the latest sensor information. It will wait for MQTT messages and update as they are received. If no message has been received yet, the display should indicate it is waiting for a new message. Each tile will be hold data for unique deviceID+deviceType+node. I.e. one tile will be displaying data from deviceType="temperature", deviceID="1", and node="rpi". Another tile will display for deviceType="humidity", deviceID="1", and node="esp32" and et cetera. Currently, there is only one sensor per sensorType, so device ID should always be 1. 

### InfluxDB Time-Series Database

InfluxDB stores historical sensor data and device states for analytics and charting. The data is organized using InfluxDB's tag-based structure:

- **Measurement**: sensor, device, or actuator
- **Tags**: Indexed metadata with the following tags: location, deviceType, deviceID, deviceNode,project
- **Fields**: Actual values (sensor readings, boolean states)
- **Timestamp**: Precise time of measurement

This structure enables efficient querying for historical charts with customizable time ranges (1h, 24h, 7d, 30d) and aggregation functions.

### Actuator Control Flow

The app **will** implement a robust control system for managing actuators:

1. **Command Publishing**: App publishes control messages to device-specific topics (e.g., `grow/esp32_1/actuator/set`)
2. **Device Processing**: Target device receives command and attempts state change
3. **State Confirmation**: Device publishes actual state via status messages
4. **Monitoring Loop**: App monitors for confirmation within timeout period
5. **Failure Handling**: Retry logic and error reporting for failed commands

This architecture ensures reliable control with feedback verification, preventing assumptions about successful state changes and providing visibility into system responsiveness.

### Network Resilience

The distributed design provides fault tolerance - individual device failures don't compromise the entire system. The app gracefully handles intermittent connectivity, offline devices, and partial system availability while maintaining core monitoring functionality.

## Data Flow Overview

This section describes how data moves through the Hydroponic Monitor system:

1. **Sensors** (temperature, humidity, pH, EC, water level, etc.) collect readings on ESP32 or Raspberry Pi nodes.
2. **Microcontrollers** publish sensor data to the MQTT broker using namespaced topics (`grow/{node}/{deviceCategory}`).
3. **App** subscribes to relevant MQTT topics and receives real-time sensor and actuator status messages.
4. **Dashboard Tiles** update immediately as new MQTT messages arrive, showing the latest values for each device.
5. **Historical Data** is queried from InfluxDB for charts and analytics; only reads are performed by the app.
6. **Actuator Commands** are sent by the app via MQTT to device-specific topics; devices confirm state changes by publishing status messages.
7. **Offline Handling**: If the app loses connection to MQTT or InfluxDB, it displays appropriate status and resumes updates when reconnected.

## Data Flow Diagram

Below is a simplified diagram showing how data flows through the Hydroponic Monitor app:
```mermaid
flowchart TD
    A[Sensors/Actuators] --> B[ESP32/Raspberry Pi Nodes]
    B --> C[MQTT Broker]
    C --> D[MQTT Client (data/mqtt/)]
    D --> E[Repositories (data/repos/)]
    E --> F[Providers (presentation/providers/)]
    F --> G[Streams]
    G --> H[Dashboard/Controls/Charts Screens]
    H --> I[Sensor/Device Tiles (presentation/widgets/)]

    %% Actuator control feedback loop
    H -.->|Actuator Commands| C
    C -.->|State Confirmation| D

    %% Historical data flow
    H --> J[InfluxDB Client (data/influx/)]
    J --> E

    %% Connection status
    F --> K[Connection Notification (presentation/widgets/connection_notification.dart)]
```

- **Sensor/Actuator data** is published via MQTT.
- **MQTT client** receives messages and updates repositories.
- **Repositories** expose data via **streams**.
- **Providers** (Riverpod) listen to streams and manage state.
- **UI screens** and **tiles** subscribe to providers for real-time updates.

> For more detail, see the architecture and operational instructions in `.github/`.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.
