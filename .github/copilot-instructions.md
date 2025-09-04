# Hydroponic Monitor App - Development Instructions

**ALWAYS follow these instructions first before searching or running bash commands. Only fallback to additional search and context gathering if the information in these instructions is incomplete or found to be in error.**

## Repository State

This repository contains a fully functional Flutter hydroponic monitoring application:
- `.github/copilot-instructions.md` - This file (operational instructions)
- `.github/copilot-instructions-architecture.md` - Architecture and coding standards
- `.github/workflows/ci.yml` - Complete CI/CD pipeline with unit and integration tests
- `.github/workflows/copilot-end-steps.yml` - Automated test execution workflow for Copilot Agent
- `lib/` - Complete Flutter application source code
- `test/` - Comprehensive unit and integration test suite (80 unit tests + 5 integration tests)
- `scripts/` - Test automation scripts for local and CI execution


## Environment Setup

**NEVER CANCEL builds or long-running commands. Set timeouts appropriately.**

### Prerequisites
Environment setup is handled by the GitHub workflow, but for manual setup:
```bash
# Dart and Flutter should already be installed via setup-dart and flutter-action
dart --version     # Should show Dart 3.9.0+
flutter --version  # Should show Flutter 3.35.2+
flutter doctor -v  # Check environment - takes ~12.5 seconds
```

### Required Dependencies for Integration Tests
```bash
# Docker and Docker Compose are required for integration tests
docker --version          # Check Docker installation
docker compose --version  # Check Docker Compose installation
```

### Environment Issues and Solutions
```bash
# If flutter analyze shows 5 style warnings, they are non-blocking:
# - prefer_const_literals_to_create_immutables (2 issues)
# - unnecessary_underscores (1 issue) 
# - prefer_single_quotes (2 issues)
# These can be fixed but don't block builds or tests

# If GTK3 headers missing for Linux builds:
# sudo apt install libgtk-3-dev mesa-utils
# Note: Linux desktop builds not available in sandbox environments
```

## Automated Test Execution

**The Copilot Agent must run comprehensive tests after commits and task completion.**

### Test Automation Workflow Scripts

**ALWAYS run the complete test suite using the test automation scripts:**

```bash
# Recommended: Use the comprehensive test runner
./scripts/test-runner.sh --all --verbose --coverage
# Runs both unit tests (80) and integration tests (5)
# Takes ~95 seconds total - NEVER CANCEL, use timeout 600+
```

### Test Execution Requirements

**Unit Tests (ALWAYS run first):**
```bash
flutter test --exclude-tags=integration --coverage --reporter=expanded
# 80 tests covering entities, repositories, services, and widgets
# Takes ~18 seconds - NEVER CANCEL, use timeout 120+
```

**Integration Tests (run after unit tests pass):**
```bash
# Requires Docker Compose services: InfluxDB, MQTT Broker, Telegraf
cd test/integration && docker compose up -d
# Wait for services to be healthy (up to 5 minutes)
flutter test test/integration/ --reporter=expanded --timeout=240s
# Tests full MQTT → Telegraf → InfluxDB pipeline
# Takes ~62 seconds - NEVER CANCEL, use timeout 300+
```

### Test Failure Investigation

**When tests fail, Copilot Agent MUST:**

1. **Analyze the failure output** - Read error messages, stack traces, and failure logs
2. **Check service logs** - For integration test failures, examine Docker service logs:
   ```bash
   cd test/integration
   docker compose logs influxdb --tail=100
   docker compose logs mosquitto --tail=100  
   docker compose logs telegraf --tail=100
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
6. **Report results** and any fixes made

### Dependencies and Analysis
```bash
flutter pub get          # ~1.5 seconds
flutter analyze          # ~13.5 seconds - NEVER CANCEL, use timeout 60+
dart format --output none --set-exit-if-changed .  # ~1 second
```

### Build Commands and Timing
```bash
flutter build web        # ~34 seconds - NEVER CANCEL, use timeout 300+
flutter build apk --debug # Not tested in sandbox environment
flutter build linux      # Requires GTK3 headers (not available in sandbox)
```

### Test Execution Timing
```bash
# Unit tests only
flutter test --exclude-tags=integration # ~18 seconds - NEVER CANCEL, use timeout 120+

# Integration tests only (requires Docker)
./scripts/run-integration-tests.sh       # ~62 seconds - NEVER CANCEL, use timeout 300+

# Complete test suite (unit + integration)
./scripts/test-runner.sh --all --verbose # ~95 seconds - NEVER CANCEL, use timeout 600+
```

### Development Server
```bash
# Web development server
flutter run -d web-server --web-port 8080 # ~24 seconds to start - NEVER CANCEL, use timeout 180+
# Serves at http://localhost:8080
```

## Validation Scenarios

**ALWAYS test these scenarios after making changes:**

1. **Basic Build Validation**:
   ```bash
   flutter pub get && flutter analyze && flutter test --exclude-tags=integration
   # Takes ~33 seconds total - NEVER CANCEL, use timeout 240+
   ```

2. **Complete Test Suite Validation**:
   ```bash
   ./scripts/test-runner.sh --all --verbose --coverage
   # Includes unit tests (80) and integration tests
   # Takes ~95 seconds - NEVER CANCEL, use timeout 600+
   ```

3. **Code Quality Checks**:
   ```bash
   dart format --output none --set-exit-if-changed .
   flutter analyze  # Must show "No issues found!" (currently shows 5 minor style issues)
   ```

4. **Application Functionality Validation**:
   ```bash
   # Start web server and verify app loads
   flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0
   # App serves at http://localhost:8080
   # Verify dashboard loads with no runtime errors
   ```

5. **Docker Integration Test Environment**:
   ```bash
   # Test Docker services can start
   cd test/integration && docker compose up -d
   # Verify all services are healthy
   docker compose ps
   # Clean up
   docker compose down -v
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

## CI Integration

The `.github/workflows/ci.yml` handles the complete CI/CD pipeline including:
- Code formatting and analysis
- Unit tests (80 tests)
- Integration tests (5 tests) with Docker Compose services
- Test result reporting and failure handling

The `.github/workflows/copilot-end-steps.yml` documents a flow for testing for Copilot Agent:
- Runs comprehensive test suite
- Reports results

## Quick Command Reference

**All commands tested and validated with exact timings:**

```bash
# Environment check
flutter doctor -v                                    # 12.5s

# Dependencies
flutter pub get                                       # 1.5s

# Code quality
dart format --output none --set-exit-if-changed .    # 1s
flutter analyze                                       # 13.5s (shows 5 style warnings)

# Testing
flutter test --exclude-tags=integration              # 18s (80 tests)
./scripts/run-integration-tests.sh                   # 62s (5 tests)
./scripts/test-runner.sh --all --verbose             # 95s (85 total tests)

# Building
flutter build web                                     # 34s

# Running
flutter run -d web-server --web-port 8080            # 24s to start
```

**NEVER CANCEL any command above. Use appropriate timeouts (shown) + 50% buffer.**