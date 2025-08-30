import 'package:flutter_test/flutter_test.dart';
import 'package:hydroponic_monitor/core/logger.dart';

void main() {
  group('Logger', () {
    test('should redact sensitive information', () {
      // Arrange
      const inputWithSecrets = '''
        {
          "password": "secret123",
          "token": "abc123def456",
          "api_key": "xyz789",
          "username": "user1"
        }
      ''';
      
      // Act
      final redacted = Logger.redactSecrets(inputWithSecrets);
      
      // Assert
      expect(redacted, contains('***redacted***'));
      expect(redacted, isNot(contains('secret123')));
      expect(redacted, isNot(contains('abc123def456')));
      expect(redacted, isNot(contains('xyz789')));
      expect(redacted, contains('user1')); // Username should not be redacted
    });

    test('should handle empty string', () {
      // Act
      final result = Logger.redactSecrets('');
      
      // Assert
      expect(result, isEmpty);
    });

    test('should handle string without secrets', () {
      // Arrange
      const input = 'This is a normal log message with no secrets';
      
      // Act
      final result = Logger.redactSecrets(input);
      
      // Assert
      expect(result, equals(input));
    });
  });
}