part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({this.status = AuthStatus.unknown, this.user, this.isSubmitting = false, this.failure});

  final AuthStatus status;
  final User? user;
  final bool isSubmitting;
  final Failure? failure;

  AuthState copyWith({bool? isSubmitting, Failure? failure, bool clearFailure = false}) => AuthState(
    status: status,
    user: user,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => [status, user, isSubmitting, failure];
}
