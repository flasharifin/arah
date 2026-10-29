import 'package:arah/core/error/failure.dart';
import 'package:arah/core/network/api_exception.dart';
import 'package:arah/features/auth/data/models/user_model.dart';

/// Kontrak auth mobile. Backend belum menyediakan auth bearer untuk mobile
/// (doc/designapp/05-integrasi-dan-tahapan.md), jadi baru ada implementasi fixture.
abstract interface class AuthRemoteDataSource {
  Future<AuthSession> signIn({required String email, required String password});
  Future<UserModel> me();
  Future<void> revoke();
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
}
