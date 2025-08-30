import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponic_monitor/core/logger.dart';

void main() {
  test('basic test for project setup', () {
    // Simple test to verify the project compiles
    expect(1 + 1, equals(2));
    
    // Test logger functionality
    const testMessage = 'Test message without secrets';
    final result = Logger.redactSecrets(testMessage);
    expect(result, equals(testMessage));
  });
}