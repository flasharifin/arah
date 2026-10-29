import 'package:arah/core/error/failure.dart';

/// Hasil operasi repository: sukses dengan data atau gagal dengan [Failure].
/// Repository tidak melempar exception ke presentation layer.
sealed class Result<T> {
  const Result();

  R fold<R>(R Function(Failure failure) onFailure, R Function(T data) onSuccess) => switch (this) {
    Success<T>(:final data) => onSuccess(data),
    Error<T>(:final failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class Error<T> extends Result<T> {
  const Error(this.failure);
  final Failure failure;
}
