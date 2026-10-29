import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:arah/features/auth/domain/entities/user.dart';
import 'package:arah/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._tokens);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;

  @override
  Future<Result<User?>> currentUser() async {
    if (await _tokens.readAccessToken() == null) return const Success(null);
    return guard(_remote.me);
  }

  @override
  Future<Result<User>> signIn({required String email, required String password}) => guard(() async {
    final session = await _remote.signIn(email: email, password: password);
    await _tokens.save(accessToken: session.accessToken, refreshToken: session.refreshToken);
    return session.user;
  });

  @override
  Future<void> signOut() async {
    // Token lokal tetap dihapus walau revoke gagal (mis. offline).
    await guard(_remote.revoke);
    await _tokens.clear();
  }
}
