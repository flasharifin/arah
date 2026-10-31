import 'package:arah/core/error/failure.dart';
import 'package:arah/core/security/biometric_lock.dart';
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
    required BiometricLock biometricLock,
  }) : _getCurrentUser = getCurrentUser,
       _signIn = signIn,
       _signOut = signOut,
       _deleteAccount = deleteAccount,
       _biometricLock = biometricLock,
       super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthUnlockRequested>(_onUnlock);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthDeleteAccountRequested>(_onDeleteAccount);
  }

  final GetCurrentUser _getCurrentUser;
  final SignIn _signIn;
  final SignOut _signOut;
  final DeleteAccount _deleteAccount;
  final BiometricLock _biometricLock;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final result = await _getCurrentUser(const NoParams());
    final user = result.fold((_) => null, (user) => user);
    if (user == null) return emit(const AuthState(status: AuthStatus.unauthenticated));
    if (!await _biometricLock.isEnabled()) {
      return emit(AuthState(status: AuthStatus.authenticated, user: user));
    }
    emit(AuthState(status: AuthStatus.locked, user: user));
    add(const AuthUnlockRequested()); // prompt langsung saat app dibuka, bukan setelah "Keluar"
  }

  Future<void> _onUnlock(AuthUnlockRequested event, Emitter<AuthState> emit) async {
    if (state.status != AuthStatus.locked || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    final unlocked = await _biometricLock.authenticate();
    emit(
      unlocked ? AuthState(status: AuthStatus.authenticated, user: state.user) : state.copyWith(isSubmitting: false),
    );
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    // Akun lain dari layar terkunci: cabut sesi lama (token, push, kunci biometrik) sebelum masuk.
    final lockedEmail = state.status == AuthStatus.locked ? state.user?.email.toLowerCase() : null;
    if (lockedEmail != null && event.email.trim().toLowerCase() != lockedEmail) {
      await _signOut(const NoParams());
      emit(const AuthState(status: AuthStatus.unauthenticated, isSubmitting: true));
    }
    final result = await _signIn(SignInParams(email: event.email, password: event.password));
    emit(
      result.fold(
        (failure) => state.copyWith(isSubmitting: false, failure: failure),
        (user) => AuthState(status: AuthStatus.authenticated, user: user),
      ),
    );
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    // Kunci sidik jari aktif: "Keluar" hanya mengunci; sesi dibuka lagi dengan sidik jari di layar masuk.
    if (!event.sessionExpired && state.user != null && await _biometricLock.isEnabled()) {
      return emit(AuthState(status: AuthStatus.locked, user: state.user));
    }
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
