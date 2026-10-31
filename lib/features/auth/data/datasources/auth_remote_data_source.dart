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

  /// Kirim kode reset 6 digit ke email. Server selalu sukses (tidak membocorkan email terdaftar).
  Future<void> requestPasswordReset({required String email});

  /// Ganti password dengan kode dari email. Kode salah/kedaluwarsa → validation (400).
  Future<void> resetPassword({required String email, required String code, required String newPassword});
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
  Future<UserModel> me() async => UserModel.fromJson(await _api.get('/api/mobile/auth/me') as Map<String, dynamic>);

  @override
  Future<void> revoke() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) return;
    await _api.post('/api/mobile/auth/logout', body: {'refreshToken': refreshToken});
  }

  @override
  Future<void> deleteAccount({required String password}) => _api.delete('/api/account', body: {'password': password});

  @override
  Future<void> requestPasswordReset({required String email}) =>
      _api.post('/api/auth/password/forgot', body: {'email': email});

  @override
  Future<void> resetPassword({required String email, required String code, required String newPassword}) =>
      _api.post('/api/auth/password/reset', body: {'email': email, 'code': code, 'newPassword': newPassword});
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

  @override
  Future<void> requestPasswordReset({required String email}) => Future<void>.delayed(const Duration(milliseconds: 600));

  /// Fixture: kode yang benar `123456`.
  @override
  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (code != '123456') {
      throw const ApiException(FailureCode.validation, 'Kode salah atau sudah kedaluwarsa');
    }
  }
}
