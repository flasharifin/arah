import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:arah/core/error/failure.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/network/api_exception.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Server palsu: hanya `Bearer new-access` yang diterima; refresh menukar `old-refresh`.
class _FakeServer implements HttpClientAdapter {
  int refreshCalls = 0;
  bool refreshNetworkDown = false;
  final authHeaders = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ResponseBody json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    if (options.path == '/api/mobile/auth/refresh') {
      refreshCalls++;
      if (refreshNetworkDown) {
        throw DioException.connectionError(requestOptions: options, reason: 'offline');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20)); // beri waktu request paralel menumpuk
      final body = options.data as Map<String, dynamic>;
      return body['refreshToken'] == 'old-refresh'
          ? json(200, {
              'data': {'accessToken': 'new-access', 'refreshToken': 'new-refresh'},
            })
          : json(401, {'error': 'Sesi berakhir, silakan masuk lagi'});
    }
    if (options.path == '/api/mobile/auth/login') return json(401, {'error': 'Email atau password salah'});

    authHeaders.add(options.headers['Authorization'] as String?);
    return options.headers['Authorization'] == 'Bearer new-access'
        ? json(200, {
            'data': [1, 2, 3],
          })
        : json(401, {'error': 'Unauthorized'});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeServer server;
  late TokenStorage tokens;
  late ApiClient api;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'old-access', 'refresh_token': 'old-refresh'});
    tokens = const TokenStorage(FlutterSecureStorage());
    server = _FakeServer();
    api = ApiClient(
      baseUrl: 'http://test',
      tokenStorage: tokens,
      dio: Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = server,
    );
  });

  test('access token kedaluwarsa → refresh sekali lalu ulangi request dengan token baru', () async {
    expect(await api.get('/api/portfolio'), [1, 2, 3]);
    expect(server.refreshCalls, 1);
    expect(server.authHeaders, ['Bearer old-access', 'Bearer new-access']);
    expect(await tokens.readAccessToken(), 'new-access');
    expect(await tokens.readRefreshToken(), 'new-refresh');
  });

  test('dua request paralel yang sama-sama 401 hanya memicu satu refresh', () async {
    final results = await Future.wait([api.get('/api/portfolio'), api.get('/api/summary')]);
    expect(results, [
      [1, 2, 3],
      [1, 2, 3],
    ]);
    expect(server.refreshCalls, 1);
  });

  test('refresh token ditolak → token dihapus, sessionExpired berbunyi, error unauthenticated', () async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'old-access', 'refresh_token': 'dicabut'});
    final expired = expectLater(api.sessionExpired, emits(null));
    await expectLater(
      api.get('/api/portfolio'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', FailureCode.unauthenticated)),
    );
    await expired;
    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.readRefreshToken(), isNull);
  });

  test('refresh gagal karena jaringan → token tetap disimpan untuk dicoba lagi', () async {
    server.refreshNetworkDown = true;
    var expiredFired = false;
    final sub = api.sessionExpired.listen((_) => expiredFired = true);
    await expectLater(api.get('/api/portfolio'), throwsA(isA<ApiException>()));
    await sub.cancel();
    expect(expiredFired, isFalse);
    expect(await tokens.readRefreshToken(), 'old-refresh');
  });

  test('401 dari login tidak memicu refresh', () async {
    await expectLater(
      api.post('/api/mobile/auth/login', body: {'email': 'a@b.c', 'password': 'salah-123'}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Email atau password salah')),
    );
    expect(server.refreshCalls, 0);
  });
}
