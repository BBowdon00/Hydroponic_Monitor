# Hydroponic Monitor App - Development Instructions

**ALWAYS follow these instructions first before searching or running bash commands. Only fallback to additional search and context gathering if the information in these instructions is incomplete or found to be in error.**

## Repository State

This repository contains a fully functional Flutter hydroponic monitoring application:
- `.github/copilot-instructions.md` - This file (operational instructions)
- `.github/copilot-instructions-architecture.md` - Architecture and coding standards
- `.github/workflows/ci.yml` - Complete CI/CD pipeline with unit and integration tests
- `lib/` - Complete Flutter application source code
- `test/` - Comprehensive unit and integration test suite (80 unit tests + 5 integration tests)
- `scripts/` - Test automation scripts for local and CI execution


## Environment Setup
Follow steps in .github/workflows/copilot-setup-steps.yml

## Tests
### Running Tests:
To run all tests (unit + integration) locally, execute:
```bash
./scripts/test-runner.sh --all --verbose
```


### On Failure
**When tests fail, Copilot Agent MUST:**

1. **Analyze the failure output** - Read error messages, stack traces, and failure logs
2. **Check service logs** - For integration test failures, examine Docker service logs:
   ```bash
   cat test/logs/*.log
   ```
3. **Identify root cause** - Distinguish between:
   - Code logic errors (fix in source code)
   - Test environment issues (fix test setup)
   - Service configuration problems (fix Docker/config files)
   - Timing issues (adjust timeouts)
4. **Implement surgical fixes** - Make minimal changes to fix the specific failure
5. **Verify fix** - Re-run failed tests to confirm resolution
6. **Run full test suite** - Ensure no regressions were introduced

## Project Structure
See ..\README.md for detailed project background and backend infrastructure.
```
[repo-root]/
├── .github/                 # GitHub configuration
│   ├── workflows/
│   │   └── copilot-setup-steps.yml  # instructions for Copilot Agent
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
./scripts/test-runner.sh --all --verbose             # 95s (85 total tests)

# Building
flutter build web                                     # 34s

# Running
flutter run -d web-server --web-port 8080            # 24s to start
```

**NEVER CANCEL any command above. Use appropriate timeouts (shown) + 50% buffer.**