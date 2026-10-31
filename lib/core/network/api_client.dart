import 'dart:async';

import 'package:arah/core/error/failure.dart';
import 'package:arah/core/network/api_exception.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:dio/dio.dart';

/// HTTP client tunggal. Menyisipkan token, memperbarui access token yang kedaluwarsa,
/// dan memetakan error Dio ke [ApiException].
class ApiClient {
  ApiClient({required String baseUrl, required TokenStorage tokenStorage, Dio? dio})
    : _tokens = tokenStorage,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.readAccessToken();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokens;
  final _sessionExpired = StreamController<void>.broadcast();

  // Refresh yang sedang berjalan dipakai bersama: refresh token dirotasi server, jadi dua refresh
  // paralel dengan token yang sama membuat salah satunya ditolak dan sesi terputus.
  Future<bool>? _refreshing;

  /// Berbunyi saat sesi tidak bisa diperbarui lagi (refresh token ditolak); token lokal sudah dihapus.
  Stream<void> get sessionExpired => _sessionExpired.stream;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) => _send(() => _dio.post<dynamic>(path, data: body));

  Future<dynamic> put(String path, {Object? body}) => _send(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) => _send(() => _dio.patch<dynamic>(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) => _send(() => _dio.delete<dynamic>(path, data: body));

  /// Backend mengembalikan `{ data }` untuk semua response sukses (doc/designapp/07, G6).
  static dynamic unwrap(dynamic body) => body is Map<String, dynamic> && body.containsKey('data') ? body['data'] : body;

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return unwrap(response.data);
    } on DioException catch (e) {
      // Access token kedaluwarsa (15 menit): perbarui sekali lalu ulangi request yang sama.
      if (e.response?.statusCode == 401 && !_isAuthPath(e.requestOptions.path) && await _refresh()) {
        try {
          final response = await request();
          return unwrap(response.data);
        } on DioException catch (retry) {
          throw _map(retry);
        }
      }
      throw _map(e);
    }
  }

  // 401 dari login/refresh/logout = kredensial salah atau sesi berakhir, bukan token kedaluwarsa.
  static bool _isAuthPath(String path) => path.startsWith('/api/mobile/auth/');

  Future<bool> _refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post<dynamic>('/api/mobile/auth/refresh', data: {'refreshToken': refreshToken});
      final data = unwrap(response.data) as Map<String, dynamic>;
      await _tokens.save(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String);
      return true;
    } on DioException catch (e) {
      // Hanya 401 yang pasti mengakhiri sesi; gagal jaringan biarkan token untuk dicoba lagi.
      if (e.response?.statusCode == 401) {
        await _tokens.clear();
        _sessionExpired.add(null);
      }
      return false;
    }
  }

  ApiException _map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const ApiException(FailureCode.timeout, 'Server terlalu lama merespons.');
      case DioExceptionType.connectionError:
        return const ApiException(FailureCode.network, 'Tidak ada koneksi internet.');
      default:
        break;
    }
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final serverMessage = data is Map && data['error'] is String ? data['error'] as String : null;
    final code = switch (status) {
      401 => FailureCode.unauthenticated,
      400 || 422 => FailureCode.validation,
      404 => FailureCode.notFound,
      429 => FailureCode.rateLimited,
      final s? when s >= 500 => FailureCode.server,
      _ => FailureCode.unknown,
    };
    return ApiException(code, serverMessage ?? 'Terjadi kesalahan (${status ?? '-'}).');
  }
}
