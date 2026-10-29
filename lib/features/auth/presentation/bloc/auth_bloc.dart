import 'package:arah/core/error/failure.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/auth/domain/entities/user.dart';
import 'package:arah/features/auth/domain/usecases/auth_usecases.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required GetCurrentUser getCurrentUser,
    required SignIn signIn,
    required SignOut signOut,
    required DeleteAccount deleteAccount,
  }) : _getCurrentUser = getCurrentUser,
       _signIn = signIn,
       _signOut = signOut,
       _deleteAccount = deleteAccount,
       super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthDeleteAccountRequested>(_onDeleteAccount);
  }

  final GetCurrentUser _getCurrentUser;
  final SignIn _signIn;
  final SignOut _signOut;
  final DeleteAccount _deleteAccount;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final result = await _getCurrentUser(const NoParams());
    emit(
      result.fold(
        (_) => const AuthState(status: AuthStatus.unauthenticated),
        (user) => user == null
            ? const AuthState(status: AuthStatus.unauthenticated)
            : AuthState(status: AuthStatus.authenticated, user: user),
      ),
    );
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    final result = await _signIn(SignInParams(email: event.email, password: event.password));
    emit(
      result.fold(
        (failure) => state.copyWith(isSubmitting: false, failure: failure),
        (user) => AuthState(status: AuthStatus.authenticated, user: user),
      ),
    );
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _signOut(const NoParams());
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onDeleteAccount(AuthDeleteAccountRequested event, Emitter<AuthState> emit) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    final result = await _deleteAccount(event.password);
    emit(
      result.fold(
        (failure) => state.copyWith(isSubmitting: false, failure: failure),
        (_) => const AuthState(status: AuthStatus.unauthenticated),
      ),
    );
  }
}
