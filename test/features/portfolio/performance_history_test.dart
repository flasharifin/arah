import 'package:arah/core/domain/money.dart';
import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:arah/core/theme/app_theme.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';
import 'package:arah/features/dividends/domain/repositories/dividend_repository.dart';
import 'package:arah/features/dividends/domain/usecases/get_dividends.dart';
import 'package:arah/features/dividends/presentation/bloc/dividends_cubit.dart';
import 'package:arah/features/portfolio/data/datasources/performance_remote_data_source.dart';
import 'package:arah/features/portfolio/data/repositories/performance_repository_impl.dart';
import 'package:arah/features/portfolio/domain/entities/performance.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/domain/repositories/portfolio_repository.dart';
import 'package:arah/features/portfolio/domain/usecases/get_portfolio.dart';
import 'package:arah/features/portfolio/domain/usecases/performance_usecases.dart';
import 'package:arah/features/portfolio/presentation/bloc/performance_cubit.dart';
import 'package:arah/features/portfolio/presentation/bloc/portfolio_bloc.dart';
import 'package:arah/features/portfolio/presentation/widgets/performance_tab.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FakeRemote implements PerformanceRemoteDataSource {
  _FakeRemote(this.rows, this.sales);
  final List<DailyPerformance> rows;
  final List<SaleRecord> sales;

  @override
  Future<List<DailyPerformance>> fetchDaily() async => rows;

  @override
  Future<List<SaleRecord>> fetchSales() async => sales;
}

class _FakePortfolioRepo implements PortfolioRepository {
  _FakePortfolioRepo(this.portfolio);
  final Portfolio portfolio;

  @override
  Future<Result<Portfolio>> getPortfolio() async => Success(portfolio);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDividendRepo implements DividendRepository {
  _FakeDividendRepo(this.items, {this.fails = false});
  final List<Dividend> items;
  final bool fails;

  @override
  Future<Result<List<Dividend>>> list() => guard(() async => fails ? throw Exception('gagal') : items);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DateTime _daysAgo(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - days);
}

DailyPerformance _row(DateTime date, double pnl, double pct) => DailyPerformance(
  date: date,
  portfolioValue: const Money.idr(100000000),
  pnl: Money.idr(pnl),
  pnlPercent: pct,
);

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  Future<PrivacyCubit> pump(
    WidgetTester tester,
    List<DailyPerformance> rows, {
    double textScale = 1,
    Portfolio portfolio = const Portfolio(positions: []),
    List<SaleRecord> sales = const [],
    List<Dividend> dividends = const [],
    bool dividendsFail = false,
  }) async {
    tester.view.physicalSize = const Size(360, 4000); // semua kartu terbangun tanpa perlu menggulir
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final privacy = PrivacyCubit();
    addTearDown(privacy.close);
    final repository = PerformanceRepositoryImpl(_FakeRemote(rows, sales));
    final portfolioRepo = _FakePortfolioRepo(portfolio);
    final dividendRepo = _FakeDividendRepo(dividends, fails: dividendsFail);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: privacy),
          BlocProvider(create: (_) => PerformanceCubit(GetDailyPerformance(repository))..load()),
          BlocProvider(create: (_) => SalesCubit(GetSales(repository))..load()),
          BlocProvider(create: (_) => PortfolioBloc(GetPortfolio(portfolioRepo))..add(const PortfolioRequested())),
          BlocProvider(
            create: (_) => DividendsCubit(
              get: GetDividends(dividendRepo),
              save: SaveDividend(dividendRepo),
              remove: RemoveDividend(dividendRepo),
              getPortfolio: GetPortfolio(portfolioRepo),
            )..load(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(body: PerformanceTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return privacy;
  }

  group('total return', () {
    const bbca = Position(
      id: 'bbca',
      symbol: 'BBCA',
      exchange: Exchange.idx,
      broker: '',
      quantity: 1,
      avgPrice: Money.idr(1000),
      lastPrice: Money.idr(1100),
    );
    const nvda = Position(
      id: 'nvda',
      symbol: 'NVDA',
      exchange: Exchange.us,
      broker: '',
      quantity: 2,
      avgPrice: Money.usd(100),
      lastPrice: Money.usd(150),
    );
    final rows = [_row(_daysAgo(2), 1000, 1), _row(_daysAgo(1), 1000, 1)];
    final paid = Dividend(
      id: 'd',
      portfolioId: 'bbca',
      symbol: 'BBCA',
      dps: 1,
      paymentDate: _daysAgo(5),
      received: const Money.idr(3000),
    );

    testWidgets('rupiah & dolar terpisah, nominal tersembunyi saat privasi', (tester) async {
      final privacy = await pump(tester, rows, portfolio: const Portfolio(positions: [bbca, nvda]), dividends: [paid]);
      expect(find.text('Rupiah'), findsOneWidget);
      expect(find.text('Dolar AS'), findsOneWidget);
      final idr = Fmt.money(const Money.idr(13000), signed: true); // 10.000 + 3.000
      final usd = Fmt.money(const Money.usd(100), signed: true);
      expect(find.text(idr), findsOneWidget);
      expect(find.text(usd), findsWidgets);

      privacy.toggle();
      await tester.pumpAndSettle();
      expect(find.text(idr), findsNothing);
      expect(find.text(usd), findsNothing);
    });

    testWidgets('salah satu data gagal: total tidak tampil setengah', (tester) async {
      await pump(tester, rows, portfolio: const Portfolio(positions: [bbca]), dividendsFail: true);
      expect(find.text('Total return belum bisa dimuat.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(find.text('Posisi yang masih dipegang'), findsNothing);
    });

    testWidgets('posisi tanpa harga diberi peringatan', (tester) async {
      await pump(
        tester,
        rows,
        portfolio: const Portfolio(
          positions: [
            bbca,
            Position(id: 'x', symbol: 'XXXX', exchange: Exchange.idx, broker: '', quantity: 1, avgPrice: Money.idr(1000)),
          ],
        ),
      );
      expect(find.textContaining('XXXX belum punya harga terbaru'), findsOneWidget);
    });
  });

  testWidgets('daftar periode menampilkan selisih return terhadap indeks', (tester) async {
    await pump(tester, [
      DailyPerformance(
        date: _daysAgo(1),
        portfolioValue: const Money.idr(100000000),
        pnl: const Money.idr(2000000),
        pnlPercent: 2,
        ihsgChange: 0.5,
        btcChange: 3,
      ),
    ]);
    expect(find.text('vs IHSG ${Fmt.percent(1.5)} · BTC ${Fmt.percent(-1)}'), findsOneWidget);
  });

  testWidgets('ringkasan: streak, hari untung, puncak, drawdown; hanya persen sehingga aman saat privasi', (tester) async {
    final peak = _daysAgo(3);
    final trough = _daysAgo(2);
    final privacy = await pump(tester, [_row(peak, 1000000, 10), _row(trough, -500000, -20), _row(_daysAgo(1), -100000, -1)]);

    expect(find.text('Ringkasan kinerja'), findsOneWidget);
    expect(find.text('Berturut-turut rugi'), findsOneWidget);
    expect(find.text('2 hari'), findsNWidgets(2)); // streak di ringkasan & jumlah rugi di kalender
    expect(find.text('1 dari 3 hari bergerak'), findsOneWidget);
    expect(find.text('Puncak ${Fmt.date(peak)}'), findsOneWidget);
    expect(find.text('Terdalam ${Fmt.date(_daysAgo(1))}'), findsOneWidget);
    expect(find.text(Fmt.percent(-20.8)), findsWidgets);

    privacy.toggle();
    await tester.pumpAndSettle();
    expect(find.text('Berturut-turut rugi'), findsOneWidget);
    expect(find.text(Fmt.percent(-20.8)), findsWidgets);
  });

  testWidgets('ringkasan: belum pernah turun tampil di puncak', (tester) async {
    await pump(tester, [_row(_daysAgo(2), 1000000, 1), _row(_daysAgo(1), 1000000, 1)]);
    expect(find.text('Di puncak'), findsOneWidget);
    expect(find.text('Belum pernah turun'), findsOneWidget);
    expect(find.text('Berturut-turut untung'), findsOneWidget);
  });

  testWidgets('kalender: hitung hari, default hari terbaru, ketuk kotak menampilkan detailnya', (tester) async {
    final semantics = tester.ensureSemantics();
    final loss = _daysAgo(3);
    await pump(tester, [
      _row(loss, -500000, -0.5),
      _row(_daysAgo(2), 1000000, 1),
      _row(_daysAgo(1), 0, 0),
    ]);

    expect(find.text('Kalender PnL'), findsOneWidget);
    expect(find.text('Sejak ${Fmt.date(loss)} · 3 hari tercatat'), findsOneWidget);
    expect(find.text('1 hari'), findsNWidgets(4)); // kalender: untung, rugi, datar; ringkasan: streak

    final detail = '${Fmt.money(const Money.idr(-500000), signed: true)} (${Fmt.percent(-0.5)})';
    expect(find.text(detail), findsNothing);
    await tester.tap(find.bySemanticsLabel('${Fmt.date(loss)}, ${Fmt.percent(-0.5)}'));
    await tester.pump();
    expect(find.text(detail), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('nilai: ganti Bulan/Kuartal/Tahun, grafik 12 batang terakhir, daftar tetap lengkap', (tester) async {
    final last = _daysAgo(1);
    final rows = [
      for (var i = 13; i >= 0; i--) _row(DateTime(last.year, last.month - i, 1), 1000, 0.1),
    ];
    await pump(tester, rows);

    BarChart chart() => tester.widget<BarChart>(find.byType(BarChart));
    final oldest = PerformanceGranularity.month.labelOf(rows.first.date);
    expect(chart().data.barGroups, hasLength(12));
    expect(find.text(oldest), findsOneWidget); // di luar grafik, tetap ada di daftar

    final groups = {for (final g in PerformanceGranularity.values) g: groupByPeriod(rows, g)};
    for (final g in [PerformanceGranularity.quarter, PerformanceGranularity.year]) {
      await tester.tap(find.text(g.label));
      await tester.pumpAndSettle();
      expect(chart().data.barGroups, hasLength(groups[g]!.length.clamp(0, 12)));
      expect(find.text(g.labelOf(groups[g]!.last.start)), findsWidgets);
    }
  });

  testWidgets('mode privasi menyembunyikan nominal di kartu nilai & detail kalender', (tester) async {
    final privacy = await pump(tester, [_row(_daysAgo(2), 1000000, 1), _row(_daysAgo(1), 1000000, 1)]);
    bool lineAxis() => tester.widget<LineChart>(find.byType(LineChart).last).data.titlesData.leftTitles.sideTitles.showTitles;
    bool barAxis() => tester.widget<BarChart>(find.byType(BarChart)).data.titlesData.leftTitles.sideTitles.showTitles;
    expect(find.text(Fmt.money(const Money.idr(100000000))), findsWidgets);
    expect(lineAxis() && barAxis(), isTrue);

    privacy.toggle();
    await tester.pumpAndSettle();
    expect(find.text(Fmt.money(const Money.idr(100000000))), findsNothing);
    expect(lineAxis() || barAxis(), isFalse);
    expect(find.textContaining(Fmt.hidden), findsWidgets);
  });

  testWidgets('garis mengikuti tanggal & nilai harian; batang rugi merah ke bawah, untung hijau ke atas', (tester) async {
    final last = _daysAgo(1);
    final rows = [
      DailyPerformance(
        date: DateTime(last.year, last.month - 1, 1),
        portfolioValue: const Money.idr(100000000),
        pnl: const Money.idr(-1000000),
        pnlPercent: -1,
      ),
      // Lompat tanggal & nilai melonjak karena top up: garis ikut naik, batang PnL tetap dari harga.
      DailyPerformance(
        date: DateTime(last.year, last.month, 1),
        portfolioValue: const Money.idr(150000000),
        pnl: const Money.idr(2000000),
        pnlPercent: 2,
      ),
    ];
    await pump(tester, rows);

    final line = tester.widget<LineChart>(find.byType(LineChart).last).data.lineBarsData.single;
    final gap = DateTime.utc(last.year, last.month, 1).difference(DateTime.utc(last.year, last.month - 1, 1)).inDays;
    expect(line.spots.map((s) => s.x), [0, gap]);
    expect(line.spots.map((s) => s.y), [100000000, 150000000]);

    final rods = tester.widget<BarChart>(find.byType(BarChart)).data.barGroups.map((g) => g.barRods.single).toList();
    expect(rods.map((r) => r.toY), [-1000000, 2000000]); // bukan selisih nilai 50 jt
    expect(rods.map((r) => r.color), [AppColors.negative, AppColors.positive]);
    expect(find.text('PnL per bulan'), findsOneWidget);
  });

  testWidgets('satu catatan: garis belum tampil, batang tetap ada', (tester) async {
    await pump(tester, [_row(_daysAgo(1), 1000000, 1)]);
    expect(find.text('Grafik nilai muncul setelah ada dua catatan harian.'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('tidak overflow: satu catatan dan teks besar', (tester) async {
    await pump(tester, [_row(_daysAgo(0), 0, 0)]);
    expect(tester.takeException(), isNull);

    // Nilai datar & PnL nol: kedua grafik tetap punya rentang sumbu.
    await pump(tester, [_row(_daysAgo(2), 0, 0), _row(_daysAgo(1), 0, 0)]);
    expect(tester.takeException(), isNull);

    await pump(tester, [
      _row(_daysAgo(40), -1234567, -2.5),
      _row(_daysAgo(1), 1234567, 2.5),
    ], textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
