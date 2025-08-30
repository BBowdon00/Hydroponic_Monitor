import 'package:freezed_annotation/freezed_annotation.dart';

part 'errors.freezed.dart';

/// Base failure class for error handling
@freezed
class Failure with _$Failure {
  const factory Failure.network(String message) = NetworkFailure;
  const factory Failure.mqtt(String message) = MqttFailure;
  const factory Failure.influx(String message) = InfluxFailure;
  const factory Failure.storage(String message) = StorageFailure;
  const factory Failure.validation(String message) = ValidationFailure;
  const factory Failure.unknown(String message) = UnknownFailure;
}

/// Result wrapper for error handling
@freezed
class Result<T, E> with _$Result<T, E> {
  const factory Result.success(T data) = Success<T, E>;
  const factory Result.failure(E error) = ResultFailure<T, E>;
}

/// Extensions for Result type
extension ResultExtensions<T, E> on Result<T, E> {
  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is ResultFailure<T, E>;
  
  T? get data => when(
    success: (data) => data,
    failure: (_) => null,
  );
  
  E? get error => when(
    success: (_) => null,
    failure: (error) => error,
  );
}