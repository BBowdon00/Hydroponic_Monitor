# Hydroponic Monitor

A cross-platform Flutter application to monitor and control hydroponic systems with real-time data visualization, device control, and automated alerting.

![Flutter](https://img.shields.io/badge/Flutter-3.24.5-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.5.0-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 🎯 Project Goal

Build a **cross-platform Flutter** application (Windows, Web, Android, iOS) to **monitor and control hydroponic systems** with:

- **Real-time dashboard** (water height, humidity, temperature, pH, electricity usage)
- **Device controls** (one pump, multiple fans, lighting)
- **Video feed** (live MJPEG stream from Raspberry Pi; recording support)
- **Historical charts** (trends/analytics powered by InfluxDB)
- **System alerts** (automated rules + notifications)
- **MQTT** for sensor ingest and device control

## 🏗️ Architecture Overview

### State Management & Navigation
- **State management:** [Riverpod](https://riverpod.dev/) (hooks_riverpod) for app-wide state and DI
- **Navigation:** [go_router](https://pub.dev/packages/go_router) with bottom navigation
- **Reactivity:** Streams for live sensor/MQTT updates

### Project Structure
```
lib/
├── core/                     # Shared utilities
│   ├── env.dart             # Environment configuration
│   ├── errors.dart          # Error handling & Result types
│   ├── logger.dart          # Structured logging
│   └── theme.dart           # Material 3 themes
├── data/                    # Data layer
│   ├── mqtt/               # MQTT client implementation
│   ├── influx/             # InfluxDB client implementation
│   └── repos/              # Data repositories
├── domain/                 # Business logic
│   ├── entities/           # Domain entities
│   └── usecases/          # Business use cases
└── presentation/          # UI layer
    ├── app.dart           # Main app widget
    ├── routes.dart        # Navigation configuration
    ├── pages/             # Screen widgets
    ├── widgets/           # Reusable components
    └── providers/         # Riverpod providers
```

### Key Integrations
- **MQTT:** `mqtt_client` with TLS support and auto-reconnection
- **InfluxDB:** `influxdb_client` for time-series data queries (v2, Flux)
- **Charts:** `fl_chart` for real-time data visualization
- **Video:** MJPEG streaming with latency monitoring

## 🎨 UI/UX Principles

- **Material 3 Design:** Modern, accessible interface with light/dark themes
- **Responsive:** Adaptive layouts for mobile, tablet, desktop, and web
- **8pt Grid System:** Consistent spacing and typography
- **Accessibility:** Semantic labels, contrast compliance, scalable text
- **Performance:** Optimized for smooth animations and real-time updates

## 🚀 Quick Start

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.24.5+
- [Dart SDK](https://dart.dev/get-dart) 3.5.0+
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/BBowdon00/Hydroponic_Monitor.git
   cd Hydroponic_Monitor
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment** (optional for demo)
   ```bash
   cp .env.example .env
   # Edit .env with your MQTT and InfluxDB settings
   ```

4. **Run the app**
   ```bash
   # Web
   flutter run -d chrome
   
   # Android/iOS
   flutter run
   
   # Desktop (if supported)
   flutter run -d windows  # or macos, linux
   ```

### Development Commands

```bash
# Code generation (run after changing models)
dart run build_runner build

# Format code
dart format .

# Analyze code
flutter analyze

# Run tests
flutter test

# Run tests with coverage
flutter test --coverage

# Build for production
flutter build web --release
flutter build apk --release
```

## 🧪 Testing

### Test Structure
- **Unit tests:** Core logic, providers, repositories
- **Widget tests:** UI components and user interactions  
- **Integration tests:** End-to-end workflows
- **Golden tests:** Visual regression testing

### Running Tests
```bash
# All tests
flutter test

# Specific test file
flutter test test/unit/core/logger_test.dart

# Integration tests
flutter test integration_test/

# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## 📱 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **Web** | ✅ Supported | Primary deployment target |
| **Android** | ✅ Supported | Full feature support |
| **iOS** | ✅ Supported | Full feature support |
| **Windows** | 🔄 Planned | Desktop optimization |
| **macOS** | 🔄 Planned | Desktop optimization |
| **Linux** | 🔄 Planned | Raspberry Pi deployment |

## 🔧 Configuration

### Environment Variables
Create a `.env` file from `.env.example` and configure:

```bash
# MQTT Settings
MQTT_BROKER_URL=mqtt://your-broker:1883
MQTT_USERNAME=your_username
MQTT_PASSWORD=your_password

# InfluxDB Settings  
INFLUX_URL=http://your-influx:8086
INFLUX_TOKEN=your_token
INFLUX_ORG=your_org
INFLUX_BUCKET=sensors

# Video Feed
MJPEG_URL=http://your-camera:8080/video
```

### Runtime Configuration
Use `--dart-define` for production builds:

```bash
flutter build web --dart-define=MQTT_BROKER_URL=mqtt://prod.example.com:1883
```

## 🛠️ Build & Deploy

### Web Deployment
```bash
# Build for production
flutter build web --release --web-renderer canvaskit

# Deploy to static hosting
# Output: build/web/
```

### Mobile App Stores
```bash
# Android Play Store
flutter build appbundle --release

# iOS App Store  
flutter build ipa --release
```

## 📚 References

- **Flutter Documentation:** [docs.flutter.dev](https://docs.flutter.dev/)
- **Flutter API Reference:** [api.flutter.dev](https://api.flutter.dev/)
- **Flutter Gallery:** [github.com/flutter/gallery](https://github.com/flutter/gallery)
- **Flutter Samples:** [github.com/flutter/samples](https://github.com/flutter/samples)
- **Material 3 Design:** [m3.material.io](https://m3.material.io/)
- **Riverpod Documentation:** [riverpod.dev](https://riverpod.dev/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 🐛 Issues & Support

- **Bug Reports:** [GitHub Issues](https://github.com/BBowdon00/Hydroponic_Monitor/issues)
- **Feature Requests:** [GitHub Discussions](https://github.com/BBowdon00/Hydroponic_Monitor/discussions)
- **Documentation:** [Wiki](https://github.com/BBowdon00/Hydroponic_Monitor/wiki)

---

**Built with ❤️ using [Flutter](https://flutter.dev)**