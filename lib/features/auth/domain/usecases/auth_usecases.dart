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

/// Parameter: password untuk konfirmasi.
class DeleteAccount implements UseCase<void, String> {
  const DeleteAccount(this._repository);
  final AuthRepository _repository;

  @override
  Future<Result<void>> call(String password) => _repository.deleteAccount(password: password);
}

/// Parameter: email akun.
class RequestPasswordReset implements UseCase<void, String> {
  const RequestPasswordReset(this._repository);
  final AuthRepository _repository;

  @override
  Future<Result<void>> call(String email) => _repository.requestPasswordReset(email: email.trim());
}

class ResetPasswordParams {
  const ResetPasswordParams({required this.email, required this.code, required this.newPassword});
  final String email;
  final String code;
  final String newPassword;
}

class ResetPassword implements UseCase<void, ResetPasswordParams> {
  const ResetPassword(this._repository);
  final AuthRepository _repository;

  @override
  Future<Result<void>> call(ResetPasswordParams params) =>
      _repository.resetPassword(email: params.email.trim(), code: params.code.trim(), newPassword: params.newPassword);
}
