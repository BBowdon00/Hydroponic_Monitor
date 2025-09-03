[![CI/CD Pipeline](https://github.com/BBowdon00/Hydroponic_Monitor/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/BBowdon00/Hydroponic_Monitor/actions/workflows/ci.yml)
# hydroponic_monitor

A new Flutter project.

## Getting Started

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
- **Data Sources**: MQTT (mqtt_client), InfluxDB (influxdb_client), HTTP (dio)
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
- Optional: Linux desktop development requires GTK3 development headers

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
   cp .env.example .env
   # Edit .env with your MQTT, InfluxDB, and video stream settings
   ```

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

## Configuration

The app uses environment variables for configuration. Copy `.env.example` to `.env` and update with your settings:

```bash
# MQTT Configuration
MQTT_HOST=your-mqtt-broker.local
MQTT_PORT=1883
MQTT_USERNAME=hydro_user
MQTT_PASSWORD=your_password

# InfluxDB Configuration  
INFLUX_URL=http://your-influxdb.local:8086
INFLUX_TOKEN=your_influxdb_token
INFLUX_ORG=hydroponic-monitor
INFLUX_BUCKET=sensors

# Video Stream
MJPEG_URL=http://your-camera.local:8080/stream
```

## References

- **Flutter Documentation**: https://docs.flutter.dev/
- **Flutter API Reference**: https://api.flutter.dev/
- **Flutter Gallery**: https://github.com/flutter/gallery (UI inspiration)
- **Flutter Samples**: https://github.com/flutter/samples
- **Material 3 Design**: https://m3.material.io/
- **Riverpod Documentation**: https://riverpod.dev/
- **Go Router Guide**: https://docs.page/csells/go_router

## Backend Infrastructure and Data 
The infrastructure behind the Hydroponic Monitor app consists of a distributed network of hardware devices, MQTT message broker, and InfluxDB time-series database that work together to provide real-time monitoring and control capabilities.

### Hardware Architecture

The system is built around multiple microcontroller nodes deployed throughout the hydroponic environment:

- **Ubuntu Server**: MQTT Broker, runs influxdb, and other containers
- **Raspberry Pi devices**: Primary controllers running full Linux OS, hosting cameras for MJPEG streams and managing multiple sensors/actuators
- **ESP32 microcontrollers**: Distributed sensor nodes and actuator controllers positioned strategically around growing areas
- **Sensors**: Temperature, humidity, pH, electrical conductivity (EC), water level sensors, and total power usage sensors
- **Actuators**: Water pumps, circulation fans, LED grow lights

Each device operates independently with its own sensor/actuator management while participating in the larger network ecosystem.

### MQTT Message Broker

The MQTT broker serves as the central nervous system for real-time communication between all devices and the monitoring app. It handles three primary message types:

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
   "deviceID": "1",
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

### InfluxDB Time-Series Database

InfluxDB stores historical sensor data and device states for analytics and charting. The data is organized using InfluxDB's tag-based structure:

- **Measurement**: sensor, device, or actuator
- **Tags**: Indexed metadata (deviceID, location, deviceType)
- **Fields**: Actual values (sensor readings, boolean states)
- **Timestamp**: Precise time of measurement

This structure enables efficient querying for historical charts with customizable time ranges (1h, 24h, 7d, 30d) and aggregation functions.

### Actuator Control Flow

The app implements a robust control system for managing actuators:

1. **Command Publishing**: App publishes control messages to device-specific topics (e.g., `grow/esp32_1/actuator/set`)
2. **Device Processing**: Target device receives command and attempts state change
3. **State Confirmation**: Device publishes actual state via status messages
4. **Monitoring Loop**: App monitors for confirmation within timeout period
5. **Failure Handling**: Retry logic and error reporting for failed commands

This architecture ensures reliable control with feedback verification, preventing assumptions about successful state changes and providing visibility into system responsiveness.

### Network Resilience

The distributed design provides fault tolerance - individual device failures don't compromise the entire system. The app gracefully handles intermittent connectivity, offline devices, and partial system availability while maintaining core monitoring functionality.


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing to this project.
