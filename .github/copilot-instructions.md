# Hydroponic Monitor App - Development Instructions

**ALWAYS follow these instructions first before searching or running bash commands. Only fallback to additional search and context gathering if the information in these instructions is incomplete or found to be in error.**

## Repository State

This repository is in early development. Currently contains:
- `.github/copilot-instructions.md` - This file (operational instructions)
- `.github/copilot-instructions-architecture.md` - Architecture and coding standards
- `.github/workflows/copilot-setup-steps.yml` - Flutter/Dart environment setup for CI

**NO Flutter project exists yet.** You must create one first (see Setup section).

## Environment Setup

**NEVER CANCEL builds or long-running commands. Set timeouts appropriately.**

### Prerequisites
Environment setup is handled by the GitHub workflow, but for manual setup:
```bash
# Dart and Flutter should already be installed via setup-dart and flutter-action
dart --version     # Should show Dart 3.9.0+
flutter --version  # Should show Flutter 3.35.2+
flutter doctor -v  # Check environment - takes 10 seconds
```

### Required Dependencies for Linux Desktop Builds
```bash
sudo apt-get update && sudo apt-get install -y libgtk-3-dev pkg-config
# Takes ~60 seconds. NEVER CANCEL - use timeout 120+
```

## Project Initialization

**Since no Flutter project exists yet, create one first:**

```bash
cd [repository-root]
flutter create --org com.hydroponicmonitor --project-name hydroponic_monitor .
# Takes ~3 seconds - creates Flutter project in current directory
```

**Alternative if directory is not empty:**
```bash
# Create in subdirectory first, then move files
mkdir temp_flutter && cd temp_flutter
flutter create --org com.hydroponicmonitor --project-name hydroponic_monitor .
mv * ../ && cd .. && rmdir temp_flutter
```

## Build Commands and Timing

**CRITICAL: Set timeouts appropriately and NEVER CANCEL builds.**

### Dependencies and Analysis
```bash
flutter pub get          # <1 second
flutter analyze          # ~10 seconds - NEVER CANCEL, use timeout 60+
dart format --output none --set-exit-if-changed .  # <1 second
```

### Build Targets
```bash
# Web build (recommended for development)
flutter build web        # ~22 seconds - NEVER CANCEL, use timeout 120+

# Linux desktop build (if GTK dependencies installed)
flutter config --enable-linux-desktop
flutter build linux      # ~20 seconds - NEVER CANCEL, use timeout 120+

# Android APK build 
flutter build apk --debug # May FAIL in CI due to Gradle issues - document if fails
                          # If successful: ~60 seconds - NEVER CANCEL, use timeout 300+
```

### Testing
```bash
flutter test             # ~10 seconds - NEVER CANCEL, use timeout 60+
```

## Running the Application

### Web Development Server
```bash
flutter run -d web-server --web-port 8080
# Starts in ~20 seconds
# Access at http://localhost:8080
# Type 'q' to quit, 'r' for hot reload
```

### Available Devices
```bash
flutter devices          # Check available targets
# Expected: Web Server, Chrome, Linux (if GTK installed)
```

## Validation Scenarios

**ALWAYS test these scenarios after making changes:**

1. **Basic Build Validation**:
   ```bash
   flutter pub get && flutter analyze && flutter test
   ```

2. **Web App Functionality**:
   ```bash
   flutter run -d web-server --web-port 8080 &
   sleep 25  # Wait for startup
   curl -s http://localhost:8080 | head -10  # Should show HTML
   # Manually stop with 'q' command
   ```

3. **Code Quality Checks**:
   ```bash
   dart format --output none --set-exit-if-changed .
   flutter analyze  # Must show "No issues found!"
   ```

## Common Timing Expectations

- **Project creation**: 3 seconds
- **Dependency resolution**: <1 second  
- **Code analysis**: 10 seconds - **NEVER CANCEL, timeout 60+**
- **Unit tests**: 10 seconds - **NEVER CANCEL, timeout 60+**
- **Web build**: 22 seconds - **NEVER CANCEL, timeout 120+**
- **Linux build**: 20 seconds - **NEVER CANCEL, timeout 120+**
- **Android build**: 60 seconds (may fail) - **NEVER CANCEL, timeout 300+**
- **Web server startup**: 20 seconds
- **Code formatting**: <1 second

## Troubleshooting

### Android Build Issues
Android builds may fail in CI environments due to Gradle plugin version issues:
```
Plugin [id: 'com.android.application', version: '8.9.1'] was not found
```
This is expected in headless environments. Focus on web and Linux builds for validation.

### Missing GTK Dependencies
If Linux builds fail:
```bash
sudo apt-get install -y libgtk-3-dev pkg-config
```

### Web Server Port Conflicts
If port 8080 is busy, use different port:
```bash
flutter run -d web-server --web-port 8081
```

## Project Structure (After Initialization)

```
[repo-root]/
├── .github/                 # GitHub configuration
├── lib/                     # Dart source code
│   └── main.dart           # Entry point
├── test/                    # Test files
├── web/                     # Web-specific files
├── android/                 # Android platform files
├── ios/                     # iOS platform files  
├── linux/                   # Linux platform files
├── pubspec.yaml            # Dependencies and metadata
└── analysis_options.yaml   # Linting rules
```

## Coding Standards (After Project Creation)

**See `.github/copilot-instructions-architecture.md` for detailed coding standards and architecture guidelines.**

Key points:
- **State management**: Use Riverpod (hooks_riverpod)
- **Navigation**: Use go_router  
- **Architecture**: Feature-first structure under `lib/features/`
- **Style**: Follow flutter_lints, always run `dart format`
- **Testing**: Unit tests for providers/repositories, widget tests for screens

## CI Integration

The `.github/workflows/copilot-setup-steps.yml` handles environment setup. After project creation, add Flutter-specific CI steps:

```yaml
- name: Get dependencies
  run: flutter pub get
  
- name: Analyze code
  run: flutter analyze
  
- name: Run tests  
  run: flutter test
  
- name: Build web
  run: flutter build web
```

**Remember: NEVER CANCEL long-running operations. Always use appropriate timeouts and wait for completion.**