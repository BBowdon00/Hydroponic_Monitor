# Hydroponic Monitor App - Development Instructions

**ALWAYS follow these instructions first before searching or running bash commands. Only fallback to additional search and context gathering if the information in these instructions is incomplete or found to be in error.**

## Repository State

This repository contains a fully functional Flutter hydroponic monitoring application:
- `.github/copilot-instructions.md` - This file (operational instructions)
- `.github/copilot-instructions-architecture.md` - Architecture and coding standards
- `.github/workflows/ci.yml` - Complete CI/CD pipeline with unit and integration tests
- `.github/workflows/copilot-end-steps.yml` - Automated test execution workflow for Copilot Agent
- `lib/` - Complete Flutter application source code
- `test/` - Comprehensive unit and integration test suite (50+ tests)
- `scripts/` - Test automation scripts for local and CI execution

**Flutter project is fully established** with working tests, CI/CD pipeline, and comprehensive test infrastructure.

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

### Required Dependencies for Integration Tests
```bash
# Docker and Docker Compose are required for integration tests
docker --version          # Check Docker installation
docker-compose --version  # Check Docker Compose installation

# Linux GTK dependencies for desktop builds (optional)
sudo apt-get update && sudo apt-get install -y libgtk-3-dev pkg-config
# Takes ~60 seconds. NEVER CANCEL - use timeout 120+
```

## Automated Test Execution

**The Copilot Agent must automatically run comprehensive tests after commits and task completion.**

### Test Automation Workflow

**ALWAYS run the complete test suite using the test automation scripts:**

```bash
# Recommended: Use the comprehensive test runner
./scripts/test-runner.sh --all --verbose --coverage
# Runs both unit tests (50+ tests) and integration tests
# Takes ~5-8 minutes total - NEVER CANCEL, use timeout 600+

# Alternative: Run test types separately
./scripts/test-runner.sh --unit --verbose --coverage     # Unit tests only (~2 min)
./scripts/run-integration-tests.sh                       # Integration tests only (~3-5 min)
```

### Test Execution Requirements

**Unit Tests (ALWAYS run first):**
```bash
flutter test --exclude-tags=integration --coverage --reporter=expanded
# 50+ tests covering entities, repositories, services, and widgets
# Takes ~2 minutes - NEVER CANCEL, use timeout 180+
```

**Integration Tests (run after unit tests pass):**
```bash
# Requires Docker Compose services: InfluxDB, MQTT Broker, Telegraf
cd test/integration && docker-compose up -d
# Wait for services to be healthy (up to 5 minutes)
flutter test test/integration/ --reporter=expanded --timeout=240s
# Tests full MQTT → Telegraf → InfluxDB pipeline
# Takes ~3-5 minutes total - NEVER CANCEL, use timeout 600+
```

### Test Failure Investigation

**When tests fail, Copilot Agent MUST:**

1. **Analyze the failure output** - Read error messages, stack traces, and failure logs
2. **Check service logs** - For integration test failures, examine Docker service logs:
   ```bash
   cd test/integration
   docker-compose logs influxdb --tail=100
   docker-compose logs mosquitto --tail=100  
   docker-compose logs telegraf --tail=100
   ```
3. **Identify root cause** - Distinguish between:
   - Code logic errors (fix in source code)
   - Test environment issues (fix test setup)
   - Service configuration problems (fix Docker/config files)
   - Timing issues (adjust timeouts)
4. **Implement surgical fixes** - Make minimal changes to fix the specific failure
5. **Verify fix** - Re-run failed tests to confirm resolution
6. **Run full test suite** - Ensure no regressions were introduced

### Post-Commit Test Automation

**After every commit or task completion:**

1. **Get dependencies:** `flutter pub get`
2. **Code analysis:** `flutter analyze` (must show "No issues found!")
3. **Code formatting:** `dart format --set-exit-if-changed .`
4. **Unit tests:** `flutter test --exclude-tags=integration --coverage --reporter=expanded`
5. **Integration tests:** `./scripts/run-integration-tests.sh`
6. **Generate coverage report** if all tests pass
7. **Report results** and any fixes made

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
# Unit tests (exclude integration)
flutter test --exclude-tags=integration             # ~2 minutes - NEVER CANCEL, use timeout 180+

# Integration tests (requires Docker services)
./scripts/run-integration-tests.sh                  # ~3-5 minutes - NEVER CANCEL, use timeout 600+

# Complete test suite
./scripts/test-runner.sh --all --verbose            # ~5-8 minutes - NEVER CANCEL, use timeout 600+
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
   flutter pub get && flutter analyze && flutter test --exclude-tags=integration
   ```

2. **Complete Test Suite Validation**:
   ```bash
   ./scripts/test-runner.sh --all --verbose --coverage
   # Includes unit tests (50+) and integration tests
   ```

3. **Code Quality Checks**:
   ```bash
   dart format --output none --set-exit-if-changed .
   flutter analyze  # Must show "No issues found!"
   ```

4. **Integration Test Environment**:
   ```bash
   cd test/integration
   docker-compose up -d
   # Wait for services to be healthy, then run:
   flutter test test/integration/ --reporter=expanded --timeout=240s
   ```

## Common Timing Expectations

- **Dependency resolution**: <1 second  
- **Code analysis**: 10-15 seconds - **NEVER CANCEL, timeout 60+**
- **Unit tests (50+ tests)**: 2 minutes - **NEVER CANCEL, timeout 180+**
- **Integration test setup**: 2-3 minutes (Docker services) - **NEVER CANCEL, timeout 300+**
- **Integration tests**: 2-3 minutes - **NEVER CANCEL, timeout 300+**
- **Complete test suite**: 5-8 minutes total - **NEVER CANCEL, timeout 600+**
- **Web build**: 22 seconds - **NEVER CANCEL, timeout 120+**
- **Linux build**: 20 seconds - **NEVER CANCEL, timeout 120+**
- **Android build**: 60 seconds (may fail) - **NEVER CANCEL, timeout 300+**
- **Code formatting**: <1 second

## Troubleshooting

### Integration Test Failures
Integration tests may fail due to service startup issues:
```bash
# Check service status
cd test/integration
docker-compose ps

# View service logs
docker-compose logs influxdb --tail=100
docker-compose logs mosquitto --tail=100  
docker-compose logs telegraf --tail=100

# Restart services if needed
docker-compose down && docker-compose up -d
```

### Unit Test Failures
For unit test failures, examine:
1. **Error messages** - Read the specific assertion that failed
2. **Stack traces** - Identify the failing code location  
3. **Mock expectations** - Ensure mocks are properly configured
4. **Test data** - Verify test input data is valid

### Android Build Issues
Android builds may fail in CI environments due to Gradle plugin version issues:
```
Plugin [id: 'com.android.application', version: '8.9.1'] was not found
```
This is expected in headless environments. Focus on web and Linux builds for validation.

### Docker Issues
If Docker services fail to start:
```bash
# Check Docker installation
docker --version
docker-compose --version

# Clean up Docker resources
docker system prune -f
docker-compose down -v --remove-orphans
```

## Project Structure

```
[repo-root]/
├── .github/                 # GitHub configuration
│   ├── workflows/          # CI/CD and automation workflows
│   ├── copilot-instructions.md
│   └── copilot-instructions-architecture.md
├── lib/                     # Flutter application source code
│   ├── core/               # Shared utilities (env, errors, logger, theme)
│   ├── data/               # Data layer (MQTT, InfluxDB, repositories)
│   ├── domain/             # Business logic (entities, use cases)
│   └── presentation/       # UI layer (pages, widgets, providers)
├── test/                    # Comprehensive test suite
│   ├── data/              # Repository and service tests
│   ├── domain/            # Entity and business logic tests
│   ├── presentation/      # Widget and UI tests
│   ├── integration/       # End-to-end integration tests
│   └── test_utils.dart    # Test utilities and helpers
├── scripts/                # Test automation and utility scripts
│   ├── test-runner.sh     # Comprehensive test runner
│   └── run-integration-tests.sh  # Integration test runner
├── android/                # Android platform files
├── ios/                    # iOS platform files  
├── linux/                  # Linux platform files
├── web/                    # Web platform files
├── pubspec.yaml            # Dependencies and metadata
└── analysis_options.yaml  # Linting rules
```

## Coding Standards

**See `.github/copilot-instructions-architecture.md` for detailed coding standards and architecture guidelines.**

Key points:
- **State management**: Use Riverpod (hooks_riverpod)
- **Navigation**: Use go_router  
- **Architecture**: Feature-first structure under `lib/features/`
- **Style**: Follow flutter_lints, always run `dart format`
- **Testing**: Unit tests for providers/repositories, widget tests for screens, integration tests for end-to-end flows

## CI Integration

The `.github/workflows/ci.yml` handles the complete CI/CD pipeline including:
- Code formatting and analysis
- Unit tests (50+ tests)
- Integration tests with Docker Compose services
- Test result reporting and failure handling

The `.github/workflows/copilot-end-steps.yml` handles automated testing for Copilot Agent:
- Triggered after commits and task completion
- Runs comprehensive test suite
- Investigates and fixes failures automatically
- Reports results and any fixes made

**Remember: NEVER CANCEL long-running operations. Always use appropriate timeouts and wait for completion.**