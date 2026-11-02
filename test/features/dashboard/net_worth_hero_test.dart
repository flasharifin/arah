import 'package:arah/app/di.dart';
import 'package:arah/core/domain/money.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/theme/app_theme.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:arah/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:arah/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:arah/features/dashboard/presentation/pages/home_page.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:arah/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _MockDashboard extends MockCubit<ViewState<DashboardSummary>> implements DashboardCubit {}

class _FakePush implements PushNotificationService {
  @override
  Stream<void> get pushes => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id');
    FlutterSecureStorage.setMockInitialValues({});
    configureDependencies(useFixtures: true);
    sl
      ..unregister<PushNotificationService>()
      ..registerSingleton<PushNotificationService>(_FakePush());
  });

  Future<void> pumpHome(WidgetTester tester, double netWorth) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(320, 800); // HP sempit
    addTearDown(tester.view.reset);
    final dashboard = _MockDashboard();
    whenListen(
      dashboard,
      const Stream<ViewState<DashboardSummary>>.empty(),
      initialState: ViewState<DashboardSummary>(
        status: ViewStatus.success,
        data: DashboardSummary(
          netWorth: Money.idr(netWorth),
          totalAssets: Money.idr(netWorth),
          totalLiabilities: const Money.idr(0),
          dailyChange: const Money.idr(12345678),
          dailyChangePercent: 1.25,
          asOf: DateTime.utc(2026, 11, 2, 5),
        ),
      ),
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => PrivacyCubit()),
          BlocProvider<DashboardCubit>.value(value: dashboard),
          BlocProvider(create: (_) => sl<PortfolioBloc>()),
          BlocProvider(create: (_) => sl<NetWorthCubit>()),
          BlocProvider(create: (_) => sl<UnreadNotificationsCubit>()),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomePage()),
      ),
    );
    await tester.pump();
  }

  for (final (value, shown) in [
    (128450000.0, '128.450.000'),
    (999999999.0, '999.999.999'),
    (1250000000.0, '1.250.000.000'),
  ]) {
    testWidgets('angka $shown muat di samping tombol mata, tidak keluar kartu', (tester) async {
      await pumpHome(tester, value);

      final amount = find.textContaining(shown).first;
      final eye = find.byTooltip('Sembunyikan nominal');
      expect(eye, findsOneWidget);
      expect(tester.getRect(amount).right, lessThanOrEqualTo(tester.getRect(eye).left));
      expect(tester.getRect(eye).right, lessThanOrEqualTo(320));
      expect(tester.getSize(eye).height, greaterThanOrEqualTo(44));
      // Sejajar dengan angka, di dalam kartu hijau.
      expect(find.ancestor(of: eye, matching: find.byType(HeroCard)), findsOneWidget);
    });
  }

  testWidgets('tombol mata menyembunyikan dan menampilkan nominal; tidak ada lagi di header', (tester) async {
    await pumpHome(tester, 128450000);
    expect(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Sembunyikan nominal')), findsNothing);

    await tester.tap(find.byTooltip('Sembunyikan nominal'));
    await tester.pump();
    expect(find.textContaining('128.450.000'), findsNothing);
    expect(find.byTooltip('Tampilkan nominal'), findsOneWidget);

    await tester.tap(find.byTooltip('Tampilkan nominal'));
    await tester.pump();
    expect(find.textContaining('128.450.000'), findsWidgets);
  });
}
