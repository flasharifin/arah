import 'package:arah/core/error/result.dart';

/// Kontrak use case: satu aksi bisnis, satu method `call`.
abstract interface class UseCase<T, P> {
  Future<Result<T>> call(P params);
}

/// Parameter kosong untuk use case tanpa input.
final class NoParams {
  const NoParams();
}
