import 'package:arah/core/error/failure.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/core/network/api_exception.dart';

/// Membungkus pemanggilan data source: exception diubah menjadi [Failure].
/// Dipakai semua repository impl agar penanganan error seragam.
Future<Result<T>> guard<T>(Future<T> Function() run) async {
  try {
    return Success(await run());
  } on ApiException catch (e) {
    return Error(e.toFailure());
  } catch (_) {
    return const Error(Failure(FailureCode.unknown, 'Terjadi kesalahan. Coba lagi.'));
  }
}
