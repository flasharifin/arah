import 'package:arah/core/error/failure.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/core/network/api_exception.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:arah/features/auth/data/models/user_model.dart';
import 'package:arah/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _Remote implements AuthRemoteDataSource {
  _Remote({this.wrongPassword = false});
  final bool wrongPassword;
  String? deletedWith;

  @override
  Future<void> deleteAccount({required String password}) async {
    if (wrongPassword) throw const ApiException(FailureCode.validation, 'Password salah');
    deletedWith = password;
  }

  @override
  Future<UserModel> me() => throw UnimplementedError();
  @override
  Future<void> revoke() => throw UnimplementedError();
  @override
  Future<AuthSession> signIn({required String email, required String password}) => throw UnimplementedError();
  @override
  Future<void> requestPasswordReset({required String email}) => throw UnimplementedError();
  @override
  Future<void> resetPassword({required String email, required String code, required String newPassword}) =>
      throw UnimplementedError();
}

void main() {
  const tokens = TokenStorage(FlutterSecureStorage());
  setUp(() => FlutterSecureStorage.setMockInitialValues({'access_token': 'a', 'refresh_token': 'r'}));

  test('berhasil: token dihapus SEBELUM pelepasan push (supaya tidak memicu refresh)', () async {
    final remote = _Remote();
    String? accessTokenWhenHookRuns = 'belum dipanggil';
    final repo = AuthRepositoryImpl(
      remote,
      tokens,
      beforeSignOut: () async => accessTokenWhenHookRuns = await tokens.readAccessToken(),
    );

    final result = await repo.deleteAccount(password: 'password123');

    expect(result, isA<Success<void>>());
    expect(remote.deletedWith, 'password123');
    expect(accessTokenWhenHookRuns, isNull);
    expect(await tokens.readRefreshToken(), isNull);
  });

  test('password salah: token tetap, push tidak dilepas, failure validation', () async {
    var hookCalled = false;
    final repo = AuthRepositoryImpl(
      _Remote(wrongPassword: true),
      tokens,
      beforeSignOut: () async => hookCalled = true,
    );

    final result = await repo.deleteAccount(password: 'salah-123');

    expect(result, isA<Error<void>>().having((e) => e.failure.message, 'message', 'Password salah'));
    expect(hookCalled, isFalse);
    expect(await tokens.readAccessToken(), 'a');
  });
}
