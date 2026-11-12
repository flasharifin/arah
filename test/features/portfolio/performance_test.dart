import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/dividends/data/datasources/dividend_remote_data_source.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';
import 'package:arah/features/portfolio/data/datasources/performance_remote_data_source.dart';
import 'package:arah/features/portfolio/domain/entities/performance.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends ApiClient {
  _FakeApi(this.responses) : super(baseUrl: 'http://test', tokenStorage: const TokenStorage(FlutterSecureStorage()));
  final Map<String, Object?> responses;
  final queries = <String, Map<String, dynamic>?>{};

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    queries[path] = query;
    return responses[path];
  }
}

void main() {
  test('return kumulatif majemuk, hari null datar', () {
    final r = cumulativeReturn([10, null, -10, 5]);
    expect(r[0], closeTo(10, 1e-9));
    expect(r[1], closeTo(10, 1e-9)); // bursa tutup
    expect(r[2], closeTo(-1, 1e-9)); // 1.1 × 0.9 = 0.99
    expect(r[3], closeTo(3.95, 1e-9)); // 0.99 × 1.05
    expect(cumulativeReturn([]), isEmpty);
  });

  test('periode menghitung mundur dari hari ini, termasuk hari ini', () {
    final now = DateTime(2026, 10, 31, 15);
    final days = [for (var i = 10; i >= 0; i--) DateTime(2026, 10, 31 - i)];
    final week = PerformancePeriod.week.filter(days, (d) => d, now);
    expect(week.first, DateTime(2026, 10, 25));
    expect(week, hasLength(7));
  });

  group('groupByPeriod', () {
    DailyPerformance row(DateTime date, double value, double pnl, double pct) => DailyPerformance(
      date: date,
      portfolioValue: Money.idr(value),
      pnl: Money.idr(pnl),
      pnlPercent: pct,
    );

    final rows = [
      row(DateTime(2026, 9, 30), 100, 10, 10),
      // 1 Okt: top up 1000 membuat nilai melonjak, tapi PnL harian tetap dari harga saja.
      row(DateTime(2026, 10, 1), 1100, -5, -10),
      row(DateTime(2026, 12, 31), 1150, 50, 5),
      row(DateTime(2027, 1, 1), 1160, 10, 1),
    ];

    test('bulan: nilai akhir hari terakhir, PnL dijumlah, return majemuk', () {
      final r = groupByPeriod(rows, PerformanceGranularity.month);
      expect([for (final p in r) p.start], [
        DateTime(2026, 9),
        DateTime(2026, 10),
        DateTime(2026, 12),
        DateTime(2027),
      ]);
      expect(r[1].endValue, const Money.idr(1100));
      expect(r[1].pnl, const Money.idr(-5));
    });

    test('kuartal: batas kalender & top up tidak terhitung profit', () {
      final r = groupByPeriod(rows, PerformanceGranularity.quarter);
      expect([for (final p in r) p.start], [DateTime(2026, 7), DateTime(2026, 10), DateTime(2027)]);
      expect(r[1].endValue, const Money.idr(1150));
      expect(r[1].pnl, const Money.idr(45)); // bukan 1150 − 100: top up 1000 tidak terhitung profit
      expect(r[1].returnPercent, closeTo(-5.5, 1e-9)); // 0.9 × 1.05
    });

    test('tahun: 2026 dan 2027 terpisah', () {
      final r = groupByPeriod(rows, PerformanceGranularity.year);
      expect([for (final p in r) p.start], [DateTime(2026), DateTime(2027)]);
      expect(r[0].pnl, const Money.idr(55));
      expect(r[1].endValue, const Money.idr(1160));
    });

    test('label periode', () {
      expect(PerformanceGranularity.quarter.labelOf(DateTime(2026, 10)), 'Q4 2026');
      expect(PerformanceGranularity.quarter.labelOf(DateTime(2026, 1)), 'Q1 2026');
      expect(PerformanceGranularity.year.labelOf(DateTime(2026)), '2026');
    });
  });

  test('banding indeks: majemuk per periode, hari tutup datar, tanpa data = null', () {
    DailyPerformance day(int d, double? ihsg, double? btc) => DailyPerformance(
      date: DateTime(2026, 10, d),
      portfolioValue: const Money.idr(100),
      pnl: const Money.idr(1),
      pnlPercent: 1,
      ihsgChange: ihsg,
      btcChange: btc,
    );
    final p = groupByPeriod([day(1, 10, null), day(2, null, null), day(3, -10, null)], PerformanceGranularity.month).single;
    expect(p.ihsgReturn, closeTo(-1, 1e-9)); // 1,1 × 0,9
    expect(p.sp500Return, isNull);
    expect(p.btcReturn, isNull);
  });

  group('totalReturns', () {
    final now = DateTime(2026, 11, 4);
    SaleRecord sale(Money proceeds, Money realized) => SaleRecord(
      id: 's',
      symbol: 'ASII',
      exchange: Exchange.idx,
      broker: '',
      quantity: 1,
      salePrice: proceeds,
      proceeds: proceeds,
      realizedPnl: realized,
      realizedPercent: 0,
      date: now,
    );
    Dividend dividend(Money? received, DateTime? paid) =>
        Dividend(id: 'd', portfolioId: 'p', symbol: 'BBCA', dps: 1, paymentDate: paid, received: received);
    const bbca = Position(
      id: 'bbca',
      symbol: 'BBCA',
      exchange: Exchange.idx,
      broker: '',
      quantity: 1, // 100 lembar: modal 100.000, nilai 110.000
      avgPrice: Money.idr(1000),
      lastPrice: Money.idr(1100),
    );
    const nvda = Position(
      id: 'nvda',
      symbol: 'NVDA',
      exchange: Exchange.us,
      broker: '',
      quantity: 2, // modal US$ 200, nilai US$ 300
      avgPrice: Money.usd(100),
      lastPrice: Money.usd(150),
    );

    test('dipegang + dijual + dividen per mata uang, rupiah & dolar tidak dicampur', () {
      final r = totalReturns(
        const Portfolio(positions: [bbca, nvda]),
        [sale(const Money.idr(52000), const Money.idr(2000))],
        [
          dividend(const Money.idr(3000), DateTime(2026, 1, 15)),
          dividend(const Money.usd(5), DateTime(2026, 2, 15)),
        ],
        now,
      );
      expect(r.map((t) => t.currency), [Currency.idr, Currency.usd]);
      expect(r[0].total, const Money.idr(15000)); // 10.000 + 2.000 + 3.000
      expect(r[0].percent, closeTo(10, 1e-9)); // modal 100.000 + 50.000 yang sudah dijual
      expect(r[1].total, const Money.usd(105));
      expect(r[1].percent, closeTo(52.5, 1e-9));
    });

    test('dividen belum dibayar atau belum ada nominalnya tidak dihitung', () {
      final r = totalReturns(
        const Portfolio(positions: [bbca]),
        const [],
        [dividend(const Money.idr(9000), DateTime(2026, 12)), dividend(null, DateTime(2026, 1))],
        now,
      );
      expect(r.single.dividends, const Money.idr(0));
    });

    test('posisi sudah habis dijual tetap terhitung; posisi tanpa harga dilewati', () {
      final r = totalReturns(
        const Portfolio(
          positions: [
            Position(id: 'x', symbol: 'X', exchange: Exchange.idx, broker: '', quantity: 1, avgPrice: Money.idr(1000)),
          ],
        ),
        [sale(const Money.idr(50000), const Money.idr(-10000))],
        const [],
        now,
      );
      expect(r.single.unrealized, const Money.idr(0));
      expect(r.single.total, const Money.idr(-10000));
      expect(r.single.percent, closeTo(-16.6666, 1e-3)); // modal yang sudah dijual: 60.000
    });

    test('tanpa data apa pun: kosong', () {
      expect(totalReturns(const Portfolio(positions: []), const [], const [], now), isEmpty);
    });
  });

  group('performanceStats', () {
    DailyPerformance row(int day, double pct, {double? value}) => DailyPerformance(
      date: DateTime(2026, 10, day),
      portfolioValue: Money.idr(value ?? 100),
      pnl: Money.idr(pct),
      pnlPercent: pct,
    );

    test('streak: hari datar dilewati, hari berlawanan memutus', () {
      final s = performanceStats([row(1, -1), row(2, 1), row(3, 0), row(4, 2)]);
      expect(s.streakDays, 2);
      expect(s.streakIsProfit, isTrue);
      expect(performanceStats([row(1, 1), row(2, -1)]).streakIsProfit, isFalse);
      expect(performanceStats([row(1, 0)]).streakDays, 0);
    });

    test('hari untung tidak menghitung hari datar', () {
      final s = performanceStats([row(1, 1), row(2, 0), row(3, -1), row(4, 1), row(5, 2)]);
      expect(s.profitDays, 3);
      expect(s.lossDays, 1);
      expect(s.winRatePercent, 75);
      expect(performanceStats([row(1, 0)]).winRatePercent, isNull);
    });

    test('puncak & drawdown majemuk: naik 10, turun 20, naik 5', () {
      final s = performanceStats([row(1, 10), row(2, -20), row(3, 5)]);
      expect(s.peakDate, DateTime(2026, 10, 1));
      expect(s.maxDrawdownPercent, closeTo(-20, 1e-9));
      expect(s.troughDate, DateTime(2026, 10, 2));
      expect(s.fromPeakPercent, closeTo(-16, 1e-9)); // 0,8 × 1,05
    });

    test('rugi di hari pertama terhitung drawdown dari modal awal', () {
      final s = performanceStats([row(1, -5)]);
      expect(s.maxDrawdownPercent, closeTo(-5, 1e-9));
      expect(s.troughDate, DateTime(2026, 10, 1));
    });

    test('sedang di puncak & belum pernah turun', () {
      final s = performanceStats([row(1, 1), row(2, 0), row(3, 2)]);
      expect(s.fromPeakPercent, 0);
      expect(s.maxDrawdownPercent, 0);
      expect(s.troughDate, isNull);
      expect(s.peakDate, DateTime(2026, 10, 3));
    });

    test('nilai porto turun karena jual saham bukan drawdown', () {
      final s = performanceStats([row(1, 1, value: 1000), row(2, 1, value: 400)]);
      expect(s.maxDrawdownPercent, 0);
      expect(s.fromPeakPercent, 0);
    });
  });

  test('API: pnl/daily minta 3660 baris, Decimal string & benchmark null', () async {
    final api = _FakeApi({
      '/api/pnl/daily': [
        {
          'date': '2026-10-30T00:00:00.000Z',
          'portfolioValue': '100000000',
          'pnl': '-450000',
          'pnlPct': '-0.45',
          'ihsgChange': '0.3',
          'sp500Change': null,
          'btcChange': '-1.25',
        },
      ],
    });
    final rows = await PerformanceApiDataSource(api).fetchDaily();
    expect(api.queries['/api/pnl/daily'], {'limit': '3660'});
    expect(rows.single.date, DateTime(2026, 10, 30));
    expect(rows.single.pnl, const Money.idr(-450000));
    expect(rows.single.pnlPercent, -0.45);
    expect(rows.single.ihsgChange, 0.3);
    expect(rows.single.sp500Change, isNull);
    expect(rows.single.btcChange, -1.25);
  });

  test('API: dividen memakai mata uang posisi; server lama tanpa mata uang tetap rupiah', () async {
    Map<String, Object?> row(Map<String, Object?>? portfolio) => {
      'id': 'd',
      'portfolioId': 'p',
      'stockCode': 'NVDA',
      'dps': '1',
      'taxPct': '15',
      'receivedAmount': '5.5',
      'portfolio': portfolio,
    };
    final api = _FakeApi({
      '/api/dividends': [
        row({'currency': 'USD'}),
        row({'currency': 'IDR'}),
        row(null),
      ],
    });
    final items = await DividendApiDataSource(api).list();
    expect(items.map((d) => d.received), [const Money.usd(5.5), const Money.idr(5.5), const Money.idr(5.5)]);
  });

  test('API: sales dalam mata uang aset, persen realized dari totalCost', () async {
    final api = _FakeApi({
      '/api/portfolio/sales': [
        {
          'id': 's1',
          'stockCode': 'NVDA',
          'exchange': 'US',
          'platform': 'Gotrade',
          'currency': 'USD',
          'lotSold': '2',
          'salePrice': '118.5',
          'avgCostPrice': '134.2',
          'totalProceeds': '237',
          'totalCost': '268.4',
          'realizedPnl': '-31.4',
          'saleDate': '2026-09-01T00:00:00.000Z',
          'note': null,
          'currentPrice': null,
        },
      ],
    });
    final s = (await PerformanceApiDataSource(api).fetchSales()).single;
    expect(s.exchange, Exchange.us);
    expect(s.proceeds, const Money.usd(237));
    expect(s.realizedPnl, const Money.usd(-31.4));
    expect(s.realizedPercent, closeTo(-11.70, 0.01));
    expect(s.date, DateTime(2026, 9, 1));
  });
}
