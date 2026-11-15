import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/core/theme/app_theme.dart';
import 'package:arah/features/cashflow/data/datasources/cashflow_remote_data_source.dart';
import 'package:arah/features/cashflow/data/repositories/cashflow_repository_impl.dart';
import 'package:arah/features/cashflow/domain/entities/cashflow.dart';
import 'package:arah/features/cashflow/domain/usecases/cashflow_usecases.dart';
import 'package:arah/features/cashflow/presentation/bloc/cash_movements_cubit.dart';
import 'package:arah/features/cashflow/presentation/bloc/cashflow_cubit.dart';
import 'package:arah/features/cashflow/presentation/pages/cash_movements_page.dart';
import 'package:arah/features/cashflow/presentation/widgets/cash_widgets.dart';
import 'package:arah/features/cashflow/presentation/widgets/cashflow_tab.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/presentation/bloc/net_worth_cubit.dart';
import 'package:arah/features/portfolio/data/datasources/portfolio_remote_data_source.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/domain/entities/purchase.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:arah/core/state/view_state.dart';

class _FakeApi extends ApiClient {
  _FakeApi([this.responses = const {}])
    : super(baseUrl: 'http://test', tokenStorage: const TokenStorage(FlutterSecureStorage()));
  final Map<String, Object?> responses;
  final calls = <(String, String, Object?)>[];

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add(('GET', path, query));
    return responses[path];
  }

  @override
  Future<dynamic> post(String path, {Object? body}) async => calls.add(('POST', path, body));

  @override
  Future<dynamic> put(String path, {Object? body}) async => calls.add(('PUT', path, body));
}

class _MockNetWorth extends MockCubit<ViewState<NetWorth>> implements NetWorthCubit {}

/// Aset kas di Kekayaan: Cash IDR & Cash USD (kas), Emas (bukan pilihan sumber dana).
NetWorth _netWorth() => const NetWorth(
  assets: [
    WealthItem(
      id: 'idr',
      name: 'Cash IDR',
      category: WealthCategory.cash,
      value: Money.idr(10000000),
      entry: ManualEntry(kind: WealthKind.asset, name: 'Cash IDR', category: 'cash', amount: 10000000),
    ),
    WealthItem(
      id: 'usd',
      name: 'Cash USD',
      category: WealthCategory.cash,
      value: Money.idr(1650000),
      entry: ManualEntry(kind: WealthKind.asset, name: 'Cash USD', category: 'cash', amount: 100, currency: 'USD'),
    ),
    WealthItem(
      id: 'gold',
      name: 'Emas',
      category: WealthCategory.gold,
      value: Money.idr(5000000),
      entry: ManualEntry(kind: WealthKind.asset, name: 'Emas', category: 'gold', amount: 3, currency: 'GOLD'),
    ),
  ],
  liabilities: [],
);

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  test('API: kontrak /api/cashflow & mutasi, pengaturan dikirim ke /api/settings', () async {
    final month = {
      'month': '2026-10',
      'salary': 15e6,
      'dividends': 120000,
      'otherIncome': 0,
      'totalIncome': 15.12e6,
      'invested': 2.5e6,
      'cashDelta': 4.85e6,
      'expense': 7.77e6,
      'saved': 7.35e6,
      'savingsRatePct': 48.6,
      'hasData': true,
    };
    final api = _FakeApi({
      '/api/cashflow': {
        'month': '2026-10',
        'dataSince': '2026-05-01T00:00:00.000Z',
        'usdIdr': 16500,
        'summary': {...month, 'plan': 7e6, 'vsPlan': 0.35e6},
        'series': [month],
        'assets': [
          {
            'id': 'idr',
            'name': 'Cash IDR',
            'currency': 'IDR',
            'value': 26.2e6,
            'valueIdr': 26.2e6,
            'balances': [
              {'month': '2026-10', 'valueIdr': 26.2e6},
              {'month': '2026-11', 'valueIdr': null},
            ],
          },
        ],
        'emergency': {
          'targetMonths': 6,
          'totalIdr': 26.2e6,
          'avgExpense': 7.4e6,
          'basisMonths': 3,
          'coveredMonths': 3.54,
          'shortfall': 18.2e6,
          'monthsToFull': 4,
        },
        'recent': [
          {
            'id': 'm1',
            'assetId': 'idr',
            'assetName': 'Cash IDR',
            'kind': 'purchase',
            'title': 'Beli BBCA 2 lot',
            'amount': -1902850,
            'currency': 'IDR',
            'amountIdr': -1902850,
            'balanceAfter': 26.2e6,
            'date': '2026-10-28T03:00:00.000Z',
            'reversal': false,
            'reversed': true,
          },
        ],
        'settings': {'monthlyIncome': 15e6, 'incomeDay': 25, 'incomeAssetId': 'idr', 'emergencyMonths': 6},
      },
      '/api/cashflow/movements': {
        'asset': {'id': 'usd', 'name': 'Cash USD', 'currency': 'USD', 'value': 100},
        'currency': 'USD',
        'days': 30,
        'balance': [
          {'date': '2026-10-30', 'value': 120},
          {'date': '2026-10-31', 'value': 100},
        ],
        'totalIn': 0,
        'totalOut': 20,
        'items': <Object>[],
        'truncated': false,
      },
    });
    final ds = CashflowApiDataSource(api);
    final o = await ds.overview(DateTime(2026, 10, 15));
    expect(api.calls.last.$3, {'month': '2026-10'});
    expect(o.summary.saved, 7.35e6);
    expect(o.plan, 7e6);
    expect(o.assets.single.balances.last.valueIdr, isNull, reason: 'bulan yang belum terjadi');
    expect(o.recent.single.kind, CashMovementKind.purchase);
    expect(o.recent.single.canReverse, isFalse, reason: 'sudah dibatalkan');
    expect(o.settings.hasSalary, isTrue);
    expect(o.emergency.monthsToFull, 4);

    final page = await ds.movements(assetId: 'usd');
    expect(api.calls.last.$3, {'assetId': 'usd', 'days': '30'});
    expect(page.currency, Currency.usd);
    expect(page.balance.last.value, 100);

    await ds.saveSettings(const CashflowSettings(emergencyMonths: 12));
    expect(api.calls.last.$2, '/api/settings');
    expect(api.calls.last.$3, {'monthlyIncome': null, 'incomeDay': null, 'incomeAssetId': null, 'emergencyMonths': 12});
    await ds.reverse('m1');
    expect(api.calls.last.$2, '/api/cashflow/movements/m1/reverse');
  });

  test('Catat beli: sumber dana ikut dikirim; tanpa sumber dana body tetap seperti dulu', () async {
    final api = _FakeApi();
    final ds = PortfolioApiDataSource(api);
    PositionPurchase buy({CashSource? cash}) => PositionPurchase(
      symbol: 'bbca',
      exchange: Exchange.idx,
      broker: '',
      quantity: 2,
      price: 9500,
      date: DateTime(2026, 10, 28),
      requestId: 'r1',
      cashSource: cash,
    );
    await ds.recordPurchase(buy(cash: (assetId: 'idr', amount: 1902850)));
    final body = api.calls.last.$3! as Map<String, Object?>;
    expect(body['cashAssetId'], 'idr');
    expect(body['cashAmount'], 1902850);
    await ds.recordPurchase(buy());
    expect((api.calls.last.$3! as Map).containsKey('cashAssetId'), isFalse);
  });

  group('CashSourceField', () {
    Future<List<CashSource?>> pump(WidgetTester tester, Currency currency) async {
      final emitted = <CashSource?>[];
      final netWorth = _MockNetWorth();
      when(() => netWorth.state).thenReturn(ViewState(data: _netWorth()));
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => PrivacyCubit()),
            BlocProvider<NetWorthCubit>.value(value: netWorth),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: CashSourceField(currency: currency, amount: 1900000, onChanged: emitted.add),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return emitted;
    }

    testWidgets('pilihan awal = aset kas bermata uang sama; emas tidak ditawarkan', (tester) async {
      final emitted = await pump(tester, Currency.idr);
      expect(emitted.last, (assetId: 'idr', amount: null));
      expect(find.text('Emas'), findsNothing);
      expect(find.text('Saldo Cash IDR setelah ini'), findsOneWidget);
      await tester.tap(find.text('Tidak memotong kas'));
      await tester.pump();
      expect(emitted.last, isNull);
    });

    testWidgets('saham US memakai Cash USD; jumlah yang diketik ikut dikirim', (tester) async {
      final emitted = await pump(tester, Currency.usd);
      expect(emitted.last?.assetId, 'usd');
      await tester.enterText(find.byType(TextField), '20,5');
      await tester.pump();
      expect(emitted.last, (assetId: 'usd', amount: 20.5));
    });
  });

  Widget app(Widget child, {double scale = 1}) {
    final netWorth = _MockNetWorth();
    when(() => netWorth.state).thenReturn(ViewState(data: _netWorth()));
    when(netWorth.load).thenAnswer((_) async {});
    final repo = CashflowRepositoryImpl(CashflowFixtureDataSource());
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PrivacyCubit()),
        BlocProvider<NetWorthCubit>.value(value: netWorth),
        BlocProvider(
          create: (_) => CashflowCubit(get: GetCashflow(repo), saveSettings: SaveCashflowSettings(repo))..load(),
        ),
        BlocProvider(
          create: (_) => CashMovementsCubit(get: GetCashMovements(repo), reverse: ReverseCashMovement(repo))..load(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: w!,
        ),
        home: child,
      ),
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('tab Arus kas: semua kartu tampil tanpa overflow (teks $scale×)', (tester) async {
      tester.view.physicalSize = const Size(390, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const Scaffold(body: CashflowTab()), scale: scale));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final t in [
        'Ke mana uangnya',
        'Pemasukan vs pengeluaran',
        'Saldo kas',
        'Dana darurat',
        'Mutasi kas terbaru',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Tingkat tabungan'), findsOneWidget);
    });

    testWidgets('Mutasi kas: grafik saldo, daftar per tanggal, tanpa overflow (teks $scale×)', (tester) async {
      tester.view.physicalSize = const Size(390, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const CashMovementsPage(), scale: scale));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Saldo semua kas'), findsOneWidget);
      expect(find.text('Beli BBCA 2 lot'), findsOneWidget);
    });
  }

  testWidgets('Mutasi kas: tekan mutasi → konfirmasi → dibatalkan (tercoret, ada baris pembatalan)', (tester) async {
    tester.view.physicalSize = const Size(390, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const CashMovementsPage()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beli BBCA 2 lot'));
    await tester.pumpAndSettle();
    expect(find.text('Batalkan mutasi?'), findsOneWidget);
    await tester.tap(find.text('Batalkan mutasi'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Batal: Beli BBCA 2 lot'), findsOneWidget);
    expect(find.textContaining('dibatalkan'), findsOneWidget);
  });

  testWidgets('form dari navigator root (seperti tombol Catat) tetap menampilkan Sumber dana', (tester) async {
    final netWorth = _MockNetWorth();
    when(() => netWorth.state).thenReturn(ViewState(data: _netWorth()));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        // Provider sesi di bawah navigator, seperti shell: sheet di navigator root tidak melihatnya langsung.
        home: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => PrivacyCubit()),
            BlocProvider<NetWorthCubit>.value(value: netWorth),
          ],
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  useRootNavigator: true,
                  isScrollControlled: true,
                  builder: (_) => withCashProviders(
                    context,
                    BlocProvider.value(
                      value: context.read<PrivacyCubit>(),
                      child: Material(
                        child: CashSourceField(currency: Currency.idr, onChanged: (_) {}),
                      ),
                    ),
                  ),
                ),
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(find.text('Sumber dana'), findsOneWidget);
    expect(find.text('Cash IDR'), findsOneWidget);
  });
}
