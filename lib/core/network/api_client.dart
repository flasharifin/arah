import 'package:arah/core/error/failure.dart';
import 'package:arah/core/network/api_exception.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:dio/dio.dart';

/// HTTP client tunggal. Menyisipkan token dan memetakan error Dio ke [ApiException].
class ApiClient {
  ApiClient({required String baseUrl, required TokenStorage tokenStorage, Dio? dio})
    : _dio =
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

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) => _send(() => _dio.post<dynamic>(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) => _send(() => _dio.patch<dynamic>(path, data: body));

  Future<dynamic> delete(String path) => _send(() => _dio.delete<dynamic>(path));

  /// Backend web tidak seragam: sebagian mengembalikan `{ data }`, sebagian array langsung.
  static dynamic unwrap(dynamic body) =>
      body is Map<String, dynamic> && body.containsKey('data') ? body['data'] : body;

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return unwrap(response.data);
    } on DioException catch (e) {
      throw _map(e);
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
