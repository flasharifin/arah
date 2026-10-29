import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/auth/domain/entities/user.dart';
import 'package:arah/features/auth/domain/repositories/auth_repository.dart';

class GetCurrentUser implements UseCase<User?, NoParams> {
  const GetCurrentUser(this._repository);
  final AuthRepository _repository;

  @override
  Future<Result<User?>> call(NoParams params) => _repository.currentUser();
}

class SignInParams {
  const SignInParams({required this.email, required this.password});
  final String email;
  final String password;
}

class SignIn implements UseCase<User, SignInParams> {
  const SignIn(this._repository);
  final AuthRepository _repository;

  @override
  Future<Result<User>> call(SignInParams params) =>
      _repository.signIn(email: params.email.trim(), password: params.password);
}

class SignOut implements UseCase<void, NoParams> {
  const SignOut(this._repository);
  final AuthRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) async {
    await _repository.signOut();
    return const Success(null);
  }
}
