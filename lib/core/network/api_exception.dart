import 'package:arah/core/error/failure.dart';

/// Exception dari data layer. Hanya hidup di data layer, diubah ke [Failure] oleh `guard`.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.fieldErrors = const {}});

  final FailureCode code;
  final String message;
  final Map<String, String> fieldErrors;

  Failure toFailure() => Failure(code, message, fieldErrors: fieldErrors);

  @override
  String toString() => 'ApiException($code): $message';
}
