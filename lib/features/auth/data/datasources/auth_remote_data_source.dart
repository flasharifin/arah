import 'dart:io';

import 'package:arah/core/error/failure.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/network/api_exception.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/auth/data/models/user_model.dart';

/// Kontrak auth mobile (`/api/mobile/auth/*`, doc/designapp/07-gap-backend-mobile.md).
abstract interface class AuthRemoteDataSource {
  Future<AuthSession> signIn({required String email, required String password});
  Future<UserModel> me();
  Future<void> revoke();

  /// Hapus akun + semua datanya di server. Password salah → [ApiException] validation (400).
  Future<void> deleteAccount({required String password});
}

class AuthApiDataSource implements AuthRemoteDataSource {
  const AuthApiDataSource(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  @override
  Future<AuthSession> signIn({required String email, required String password}) async {
    final data =
        await _api.post(
              '/api/mobile/auth/login',
              body: {'email': email, 'password': password, 'deviceName': Platform.operatingSystem},
            )
            as Map<String, dynamic>;
    return AuthSession(
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  @override
  Future<UserModel> me() async =>
      UserModel.fromJson(await _api.get('/api/mobile/auth/me') as Map<String, dynamic>);

  @override
  Future<void> revoke() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) return;
    await _api.post('/api/mobile/auth/logout', body: {'refreshToken': refreshToken});
  }

  @override
  Future<void> deleteAccount({required String password}) =>
      _api.delete('/api/account', body: {'password': password});
}

class AuthFixtureDataSource implements AuthRemoteDataSource {
  static const _user = UserModel(id: 'demo', name: 'Pengguna Demo', email: 'demo@arah.id');

  @override
  Future<AuthSession> signIn({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (password.length < 8) {
      throw const ApiException(FailureCode.unauthenticated, 'Email atau password salah.');
    }
    return const AuthSession(user: _user, accessToken: 'fixture', refreshToken: 'fixture');
  }

  @override
  Future<UserModel> me() async => _user;

  @override
  Future<void> revoke() async {}

  @override
  Future<void> deleteAccount({required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (password.length < 8) throw const ApiException(FailureCode.validation, 'Password salah');
  }
}
