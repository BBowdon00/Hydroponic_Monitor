/// Base class for all application errors.
abstract class AppError {
  const AppError(this.message);
  final String message;

  @override
  String toString() => 'AppError: $message';
}

/// Network-related errors.
class NetworkError extends AppError {
  const NetworkError(super.message);
}

/// MQTT connection errors.
class MqttError extends AppError {
  const MqttError(super.message);
}

/// InfluxDB query errors.
class InfluxError extends AppError {
  const InfluxError(super.message);
}

/// Data parsing/validation errors.
class DataError extends AppError {
  const DataError(super.message);
}

/// Storage/persistence errors.
class StorageError extends AppError {
  const StorageError(super.message);
}

/// Unknown/unexpected errors.
class UnknownError extends AppError {
  const UnknownError(super.message);
}

/// Initialization errors.
class NotInitializedError extends AppError {
  const NotInitializedError(super.message);
}

/// Result type for error handling.
/// Use instead of throwing exceptions across layers.
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppError error;
}
