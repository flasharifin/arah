import 'package:arah/core/error/result.dart';
import 'package:arah/core/security/biometric_lock.dart';
import 'package:arah/features/auth/domain/entities/user.dart';
import 'package:arah/features/auth/domain/repositories/auth_repository.dart';
import 'package:arah/features/auth/domain/usecases/auth_usecases.dart';
import 'package:arah/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements AuthRepository {}

class _Lock extends Mock implements BiometricLock {}

void main() {
  const user = User(id: '1', name: 'Ari', email: 'ari@example.com');
  late _Repo repo;
  late _Lock lock;

  AuthBloc build() => AuthBloc(
    getCurrentUser: GetCurrentUser(repo),
    signIn: SignIn(repo),
    signOut: SignOut(repo),
    deleteAccount: DeleteAccount(repo),
    biometricLock: lock,
  );

  setUp(() {
    repo = _Repo();
    lock = _Lock();
    when(() => repo.currentUser()).thenAnswer((_) async => const Success(user));
  });

  blocTest<AuthBloc, AuthState>(
    'sesi tersimpan + kunci aktif → locked dan prompt langsung muncul',
    setUp: () {
      when(() => lock.isEnabled()).thenAnswer((_) async => true);
      when(() => lock.authenticate()).thenAnswer((_) async => false);
    },
    build: build,
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [
      const AuthState(status: AuthStatus.locked, user: user),
      const AuthState(status: AuthStatus.locked, user: user, isSubmitting: true),
      const AuthState(status: AuthStatus.locked, user: user),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'kunci nonaktif → langsung authenticated',
    setUp: () => when(() => lock.isEnabled()).thenAnswer((_) async => false),
    build: build,
    act: (bloc) => bloc.add(const AuthStarted()),
    expect: () => [const AuthState(status: AuthStatus.authenticated, user: user)],
  );

  blocTest<AuthBloc, AuthState>(
    'biometrik gagal → tetap locked; berhasil → authenticated',
    setUp: () {
      var attempts = 0;
      when(() => lock.authenticate()).thenAnswer((_) async => ++attempts > 1);
    },
    build: build,
    seed: () => const AuthState(status: AuthStatus.locked, user: user),
    act: (bloc) async {
      bloc.add(const AuthUnlockRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AuthUnlockRequested());
    },
    expect: () => [
      const AuthState(status: AuthStatus.locked, user: user, isSubmitting: true),
      const AuthState(status: AuthStatus.locked, user: user),
      const AuthState(status: AuthStatus.locked, user: user, isSubmitting: true),
      const AuthState(status: AuthStatus.authenticated, user: user),
    ],
  );

  group('password dari layar terkunci', () {
    const other = User(id: '2', name: 'Bima', email: 'bima@example.com');
    setUp(() {
      when(() => repo.signOut()).thenAnswer((_) async {});
      when(
        () => repo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((i) async => Success(i.namedArguments[#email] == other.email ? other : user));
    });

    blocTest<AuthBloc, AuthState>(
      'akun sama: sesi tidak dicabut',
      build: build,
      seed: () => const AuthState(status: AuthStatus.locked, user: user),
      act: (bloc) => bloc.add(const AuthLoginRequested(email: ' ARI@example.com', password: 'rahasia123')),
      expect: () => [
        const AuthState(status: AuthStatus.locked, user: user, isSubmitting: true),
        const AuthState(status: AuthStatus.authenticated, user: user),
      ],
      verify: (_) => verifyNever(() => repo.signOut()),
    );

    blocTest<AuthBloc, AuthState>(
      'akun lain: sesi lama dicabut dulu (token, push, kunci)',
      build: build,
      seed: () => const AuthState(status: AuthStatus.locked, user: user),
      act: (bloc) => bloc.add(const AuthLoginRequested(email: 'bima@example.com', password: 'rahasia123')),
      expect: () => [
        const AuthState(status: AuthStatus.locked, user: user, isSubmitting: true),
        const AuthState(status: AuthStatus.unauthenticated, isSubmitting: true),
        const AuthState(status: AuthStatus.authenticated, user: other),
      ],
      verify: (_) => verify(() => repo.signOut()).called(1),
    );
  });

  group('Keluar', () {
    setUp(() => when(() => repo.signOut()).thenAnswer((_) async {}));

    blocTest<AuthBloc, AuthState>(
      'kunci aktif: hanya dikunci, sesi tidak dicabut, tanpa prompt',
      setUp: () => when(() => lock.isEnabled()).thenAnswer((_) async => true),
      build: build,
      seed: () => const AuthState(status: AuthStatus.authenticated, user: user),
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [const AuthState(status: AuthStatus.locked, user: user)],
      verify: (_) {
        verifyNever(() => repo.signOut());
        verifyNever(() => lock.authenticate());
      },
    );

    blocTest<AuthBloc, AuthState>(
      'sesi ditolak server: keluar penuh walau kunci aktif',
      setUp: () => when(() => lock.isEnabled()).thenAnswer((_) async => true),
      build: build,
      seed: () => const AuthState(status: AuthStatus.authenticated, user: user),
      act: (bloc) => bloc.add(const AuthLogoutRequested(sessionExpired: true)),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
      verify: (_) => verify(() => repo.signOut()).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'kunci nonaktif: keluar penuh',
      setUp: () => when(() => lock.isEnabled()).thenAnswer((_) async => false),
      build: build,
      seed: () => const AuthState(status: AuthStatus.authenticated, user: user),
      act: (bloc) => bloc.add(const AuthLogoutRequested()),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
      verify: (_) => verify(() => repo.signOut()).called(1),
    );
  });

  blocTest<AuthBloc, AuthState>(
    'unlock diabaikan jika tidak sedang terkunci',
    build: build,
    seed: () => const AuthState(status: AuthStatus.authenticated, user: user),
    act: (bloc) => bloc.add(const AuthUnlockRequested()),
    expect: () => <AuthState>[],
    verify: (_) => verifyNever(() => lock.authenticate()),
  );
}
