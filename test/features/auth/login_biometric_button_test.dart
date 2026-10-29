import 'package:arah/core/theme/app_theme.dart';
import 'package:arah/features/auth/domain/entities/user.dart';
import 'package:arah/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:arah/features/auth/presentation/pages/login_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  late _MockAuthBloc bloc;

  setUp(() => bloc = _MockAuthBloc());

  Future<void> pump(WidgetTester tester, AuthState state) async {
    whenListen(bloc, const Stream<AuthState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BlocProvider<AuthBloc>.value(value: bloc, child: const LoginPage()),
      ),
    );
  }

  testWidgets('belum aktif: tombol sidik jari tetap ada dan memberi pesan', (tester) async {
    await pump(tester, const AuthState(status: AuthStatus.unauthenticated));

    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pump();

    expect(find.textContaining('belum diaktifkan'), findsOneWidget);
    verifyNever(() => bloc.add(const AuthUnlockRequested()));
  });

  testWidgets('sesi terkunci: tombol sidik jari membuka sesi, email terisi', (tester) async {
    const user = User(id: '1', name: 'Ari', email: 'ari@example.com');
    await pump(tester, const AuthState(status: AuthStatus.locked, user: user));

    expect(find.text('ari@example.com'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fingerprint));
    verify(() => bloc.add(const AuthUnlockRequested())).called(1);
  });
}
