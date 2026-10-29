import 'package:equatable/equatable.dart';

/// Kode error yang distandardisasi agar UI bisa memilih pesan & aksi (mis. Coba lagi).
enum FailureCode {
  unauthenticated,
  validation,
  rateLimited,
  network,
  timeout,
  providerUnavailable,
  notFound,
  server,
  unknown,
}

class Failure extends Equatable {
  const Failure(this.code, this.message, {this.fieldErrors = const {}});

  final FailureCode code;

  /// Pesan aman untuk ditampilkan ke pengguna.
  final String message;

  /// Error per field dari server, untuk ditampilkan inline di form.
  final Map<String, String> fieldErrors;

  bool get isRetryable => switch (code) {
    FailureCode.network ||
    FailureCode.timeout ||
    FailureCode.rateLimited ||
    FailureCode.providerUnavailable ||
    FailureCode.server => true,
    _ => false,
  };

  @override
  List<Object?> get props => [code, message, fieldErrors];
}
