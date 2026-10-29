part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Buka sesi tersimpan dengan sidik jari (status [AuthStatus.locked]).
final class AuthUnlockRequested extends AuthEvent {
  const AuthUnlockRequested();
}

/// Jika kunci sidik jari aktif, sesi hanya dikunci; [sessionExpired] (token ditolak server) selalu keluar penuh.
final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested({this.sessionExpired = false});

  final bool sessionExpired;

  @override
  List<Object?> get props => [sessionExpired];
}

final class AuthDeleteAccountRequested extends AuthEvent {
  const AuthDeleteAccountRequested(this.password);

  final String password;

  @override
  List<Object?> get props => [password];
}
