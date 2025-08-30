# Contributing to Hydroponic Monitor

Thank you for your interest in contributing to the Hydroponic Monitor project! This document outlines our coding standards, development workflow, and contribution guidelines.

## 🏗️ Development Setup

### Prerequisites
- Flutter SDK 3.24.5+
- Dart SDK 3.5.0+
- IDE with Flutter support (VS Code, Android Studio, IntelliJ)
- Git

### Local Setup
1. Fork and clone the repository
2. Install dependencies: `flutter pub get`
3. Copy `.env.example` to `.env` and configure
4. Run tests to verify setup: `flutter test`

## 📏 Coding Standards

### Dart/Flutter Style
- Follow the [official Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter_lints` package rules (see `analysis_options.yaml`)
- Always run `dart format .` before committing
- Treat all analyzer warnings as errors

### Naming Conventions
- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Variables/Functions:** `camelCase`
- **Constants:** `SCREAMING_SNAKE_CASE`
- **Providers:** End with `Provider` (e.g., `sensorDataProvider`)
- **State classes:** End with `State` (e.g., `DashboardState`)

### Project Structure Rules
- **Feature-first organization:** Group related files by feature
- **Clear separation:** Keep data, domain, and presentation layers distinct
- **Reusable widgets:** Extract common UI components into `widgets/`
- **Consistent imports:** Use relative imports within features, absolute for cross-feature

### Code Quality Guidelines

#### Widget Construction
```dart
// ✅ Good: Small, focused widgets
class SensorTile extends StatelessWidget {
  const SensorTile({super.key, required this.reading});
  
  final SensorReading reading;
  
  @override
  Widget build(BuildContext context) {
    // Keep build methods < 100 lines
    return Card(/* ... */);
  }
}

// ❌ Avoid: Large, monolithic widgets
class MassiveWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 200+ lines of nested widgets
    );
  }
}
```

#### Error Handling
```dart
// ✅ Good: Use Result types for error handling
Future<Result<SensorData, Failure>> fetchSensorData() async {
  try {
    final data = await api.getSensorData();
    return Result.success(data);
  } catch (e) {
    return Result.failure(NetworkFailure(e.toString()));
  }
}

// ❌ Avoid: Throwing raw exceptions across layers
Future<SensorData> fetchSensorData() async {
  final data = await api.getSensorData(); // Can throw!
  return data;
}
```

#### Null Safety
```dart
// ✅ Good: Explicit null handling
String? getValue() => condition ? 'value' : null;

final result = getValue();
if (result != null) {
  print(result.length); // Safe
}

// ❌ Avoid: Force unwrapping without justification
final result = getValue();
print(result!.length); // Dangerous!
```

#### Async Best Practices
```dart
// ✅ Good: Proper stream management
class MyProvider extends StateNotifier<MyState> {
  StreamSubscription? _subscription;
  
  void startListening() {
    _subscription = stream.listen((data) {
      state = state.copyWith(data: data);
    });
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// ❌ Avoid: Memory leaks from uncanceled streams
class BadProvider extends StateNotifier<MyState> {
  void startListening() {
    stream.listen((data) => state = state.copyWith(data: data));
    // No cleanup = memory leak!
  }
}
```

## 🧪 Testing Standards

### Test Organization
```
test/
├── unit/                   # Unit tests for business logic
│   ├── core/              # Core utilities tests
│   ├── domain/            # Entity and use case tests
│   └── providers/         # Provider logic tests
├── widget/                # Widget tests for UI components
│   ├── pages/             # Page widget tests
│   └── widgets/           # Component widget tests
└── integration/           # End-to-end tests
    └── app_test.dart      # Full app integration tests
```

### Testing Requirements
- **Unit tests:** All providers, repositories, and use cases
- **Widget tests:** Key screens and user interactions
- **Golden tests:** Critical UI states (light/dark themes)
- **Integration tests:** End-to-end user workflows

### Test Writing Guidelines
```dart
// ✅ Good: Descriptive test names
group('SensorDataProvider', () {
  testWidgets('should emit updated readings when MQTT message received', (tester) async {
    // Arrange
    final provider = SensorDataProvider();
    final mockMqtt = MockMqttClient();
    
    // Act
    await tester.pumpWidget(/* test widget */);
    
    // Assert
    expect(find.text('22.5°C'), findsOneWidget);
  });
});

// ❌ Avoid: Vague test names
test('test provider', () {
  // What does this test?
});
```

## 🔄 Development Workflow

### Git Workflow
1. **Create feature branch:** `git checkout -b feature/sensor-alerts`
2. **Make small, focused commits:** Each commit should represent one logical change
3. **Write descriptive commit messages:** Follow [Conventional Commits](https://www.conventionalcommits.org/)
4. **Push and create PR:** Include description, screenshots, and test plan

### Conventional Commits
```bash
# Feature additions
feat: add real-time sensor data streaming
feat(dashboard): implement sensor tile animations

# Bug fixes
fix: resolve MQTT reconnection issue
fix(charts): correct time range calculation

# Documentation
docs: update API documentation
docs(readme): add installation instructions

# Refactoring
refactor: extract device control logic to provider
refactor(ui): simplify sensor tile component

# Tests
test: add unit tests for alert rules
test(widget): add dashboard integration tests

# Chores
chore: update dependencies
chore(ci): add code coverage reporting
```

## 📋 Pull Request Requirements

### PR Checklist
- [ ] **Code Quality**
  - [ ] Follows coding standards and style guide
  - [ ] All linting rules pass (`flutter analyze`)
  - [ ] Code is properly formatted (`dart format`)
  - [ ] No unused imports or dead code

- [ ] **Testing**
  - [ ] New features include unit tests
  - [ ] UI changes include widget tests
  - [ ] All tests pass (`flutter test`)
  - [ ] Coverage meets minimum threshold

- [ ] **Documentation**
  - [ ] Public APIs are documented
  - [ ] README updated if needed
  - [ ] Breaking changes are documented

- [ ] **UI/UX** (if applicable)
  - [ ] Screenshots included (light/dark themes)
  - [ ] Responsive design verified
  - [ ] Accessibility compliance checked
  - [ ] Performance impact considered

### PR Template
Use this template for all pull requests:

```markdown
## Summary
Brief description of what this PR accomplishes.

## Changes Made
- List specific changes
- Include technical details
- Mention any breaking changes

## Screenshots
Include before/after screenshots for UI changes:
- Light theme: [screenshot]
- Dark theme: [screenshot]
- Mobile/tablet/desktop views as applicable

## Test Plan
Describe how to test the changes:
1. Step-by-step testing instructions
2. Edge cases to verify
3. Performance considerations

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes (or clearly documented)
```

## 🚦 Code Review Process

### Review Criteria
- **Functionality:** Does the code work as intended?
- **Code Quality:** Is it readable, maintainable, and follows standards?
- **Performance:** Are there any performance implications?
- **Security:** Are there any security concerns?
- **Testing:** Is the code adequately tested?
- **Documentation:** Is it properly documented?

### Review Guidelines
- **Be constructive:** Provide specific, actionable feedback
- **Be timely:** Review PRs within 24-48 hours
- **Be thorough:** Check both logic and style
- **Ask questions:** If something is unclear, ask for clarification

## 📊 Performance Considerations

### General Guidelines
- **Minimize rebuilds:** Use `const` constructors and `Consumer` widgets appropriately
- **Optimize images:** Use appropriate formats and sizes
- **Lazy loading:** Implement pagination for large datasets
- **Memory management:** Dispose of controllers and cancel streams

### Specific Areas
- **Real-time data:** Throttle updates to prevent UI jank
- **Charts:** Limit data points and use sampling for large datasets
- **Images/video:** Implement caching and compression
- **Network:** Use connection pooling and request debouncing

## 🔒 Security Guidelines

### Data Handling
- **Never commit secrets:** Use environment variables or secure storage
- **Validate inputs:** Sanitize all user inputs and API responses
- **Use HTTPS:** All network communications must be encrypted
- **Secure storage:** Use `flutter_secure_storage` for sensitive data

### Code Review
- **Check for secrets:** Ensure no hardcoded passwords or tokens
- **Validate dependencies:** Review new package additions
- **Input validation:** Verify proper sanitization
- **Error messages:** Avoid exposing sensitive information

## 🎯 Feature Development Process

### Planning
1. **Create issue:** Describe the feature with user stories and acceptance criteria
2. **Design review:** Discuss UI/UX and technical approach
3. **Break down work:** Split large features into smaller PRs
4. **Estimate effort:** Consider complexity and dependencies

### Implementation
1. **Start with tests:** Write failing tests first (TDD approach)
2. **Implement incrementally:** Make small, working changes
3. **Document as you go:** Keep documentation in sync with code
4. **Seek feedback early:** Share work-in-progress for early feedback

### Quality Gates
- [ ] Feature works as specified
- [ ] Error handling is robust
- [ ] Performance is acceptable
- [ ] Accessibility requirements met
- [ ] Security review passed
- [ ] Tests provide adequate coverage

## 📞 Getting Help

### Resources
- **Documentation:** Check existing docs first
- **Code examples:** Look at similar implementations in the codebase
- **Flutter docs:** [docs.flutter.dev](https://docs.flutter.dev/)
- **Community:** [Flutter Discord](https://discord.gg/flutter)

### When to Ask for Help
- Stuck on implementation approach
- Need clarification on requirements
- Facing technical blockers
- Unsure about architectural decisions

### How to Ask
1. **Describe the problem:** What are you trying to achieve?
2. **Show what you've tried:** Include code examples and error messages
3. **Ask specific questions:** Avoid vague requests like "it doesn't work"
4. **Provide context:** Include relevant background information

## 🎉 Recognition

We appreciate all contributions, big and small! Contributors will be recognized in:
- **Release notes:** Major feature contributors
- **README:** All contributors
- **Special mentions:** Outstanding contributions

Thank you for helping make Hydroponic Monitor better! 🌱