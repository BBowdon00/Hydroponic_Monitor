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
docker compose --version  # Check Docker Compose installation
```

## Automated Test Execution

**The Copilot Agent must run comprehensive tests after commits and task completion.**

### Test Automation Workflow Scripts

**ALWAYS run the complete test suite using the test automation scripts:**

```bash
# Recommended: Use the comprehensive test runner
./scripts/test-runner.sh --all --verbose --coverage
# Runs both unit tests (50+ tests) and integration tests
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
6. **Report results** and any fixes made

## Build Commands and Timing

### Dependencies and Analysis
```bash
flutter pub get          # <1 second
flutter analyze          # ~10 seconds - NEVER CANCEL, use timeout 60+
dart format --output none --set-exit-if-changed .  # <1 second
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
- Unit tests (50+ tests)
- Integration tests with Docker Compose services
- Test result reporting and failure handling

The `.github/workflows/copilot-end-steps.yml` documents a flow for testing for Copilot Agent:
- Runs comprehensive test suite
- Reports results