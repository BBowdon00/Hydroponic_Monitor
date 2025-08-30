# Contributing to Hydroponic Monitor

Thank you for your interest in contributing to the Hydroponic Monitor project! This document provides guidelines and information for contributors.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Create a feature branch for your changes
4. Make your changes following our coding standards
5. Test your changes thoroughly
6. Submit a pull request

## Development Environment

### Prerequisites

- Flutter SDK 3.35.2+ (Dart 3.9.0+)
- Git for version control
- VS Code or Android Studio (recommended IDEs)
- For Linux builds: GTK3 development headers (`sudo apt-get install libgtk-3-dev pkg-config`)

### Setup

```bash
# Clone your fork
git clone https://github.com/your-username/Hydroponic_Monitor.git
cd Hydroponic_Monitor

# Install dependencies
flutter pub get

# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Verify setup
flutter doctor
flutter analyze
flutter test
```

## Coding Standards

### Dart/Flutter Style

- Follow the [official Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter_lints` package rules (enabled in `analysis_options.yaml`)
- Always run `dart format .` before committing
- Ensure `flutter analyze` shows zero issues

### Code Organization

- **Feature-first structure**: Group related files under `lib/features/<feature>/`
- **Layered architecture**: Separate data, domain, and presentation concerns
- **Single responsibility**: Each class should have one clear purpose
- **Dependency injection**: Use Riverpod providers for dependency management

### Naming Conventions

- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables/methods**: `camelCase`
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Providers**: End with `Provider` (e.g., `deviceStatesProvider`)
- **State classes**: End with `State` (e.g., `DeviceStates`)

### Documentation

- Add documentation comments (`///`) for public APIs
- Include usage examples for complex widgets
- Document non-obvious business logic
- Keep comments concise and current

### Error Handling

- Use `Result<T>` type for operations that can fail
- Never use `!` operator without justification
- Provide meaningful error messages
- Log errors with appropriate context

## Testing Guidelines

### Test Categories

1. **Unit Tests**: Business logic, providers, repositories
2. **Widget Tests**: UI components and user interactions  
3. **Integration Tests**: End-to-end workflows
4. **Golden Tests**: Visual regression testing

### Test Requirements

- All new features must include tests
- Maintain or improve test coverage
- Use descriptive test names
- Group related tests with `group()`
- Use appropriate matchers for clarity

### Test Examples

```dart
// Unit test
group('SensorData', () {
  test('should calculate trend correctly', () {
    final data = SensorData(value: 25.0, previousValue: 24.0);
    expect(data.trend, equals(SensorTrend.up));
  });
});

// Widget test
testWidgets('SensorTile displays correct values', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SensorTile(
        title: 'Temperature',
        value: '25.0°C',
        // ... other properties
      ),
    ),
  );
  
  expect(find.text('Temperature'), findsOneWidget);
  expect(find.text('25.0°C'), findsOneWidget);
});
```

## Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/) for clear and searchable commit history:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or modifying tests
- `chore`: Maintenance tasks

### Examples

```bash
feat(dashboard): add real-time sensor updates
fix(mqtt): handle connection timeouts gracefully
docs(readme): update installation instructions
test(widgets): add tests for device controls
```

## Pull Request Guidelines

### Before Submitting

- [ ] Code follows style guidelines
- [ ] All tests pass (`flutter test`)
- [ ] Code analysis passes (`flutter analyze`)
- [ ] Code is formatted (`dart format .`)
- [ ] New features include tests
- [ ] Documentation is updated if needed

### PR Requirements

1. **Clear title and description**: Explain what changes and why
2. **Screenshots/GIFs**: For UI changes, include before/after visuals
3. **Test plan**: Describe how you tested the changes
4. **Breaking changes**: Clearly document any breaking changes
5. **Checklist**: Complete the PR template checklist

### Review Process

- All PRs require at least one review
- Address feedback promptly and professionally
- Update documentation for user-facing changes
- Squash commits when requested

## Project Structure Guidelines

### Adding New Features

1. Create feature directory: `lib/features/my_feature/`
2. Organize by layers:
   ```
   lib/features/my_feature/
   ├── data/
   │   ├── datasources/
   │   ├── models/
   │   └── repositories/
   ├── domain/
   │   ├── entities/
   │   ├── repositories/
   │   └── usecases/
   └── presentation/
       ├── pages/
       ├── widgets/
       └── providers/
   ```

### Adding Dependencies

- Discuss major dependencies in issues first
- Prefer packages with good maintenance and documentation
- Update `pubspec.yaml` with clear comments
- Consider bundle size impact for web builds

### UI Components

- Create reusable widgets in `lib/presentation/widgets/`
- Follow Material 3 design principles
- Use theme constants from `AppTheme`
- Ensure accessibility (semantics, contrast, focus)
- Test on multiple screen sizes

## Getting Help

- **Documentation**: Check README.md and code comments first
- **Issues**: Search existing issues before creating new ones
- **Discussions**: Use GitHub Discussions for questions
- **Code Review**: Ask for specific feedback in PR comments

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help newcomers learn and contribute
- Follow GitHub's Community Guidelines

## Recognition

Contributors will be acknowledged in:
- Git commit history
- Release notes for significant contributions
- README contributor section (future)

Thank you for contributing to Hydroponic Monitor! 🌱