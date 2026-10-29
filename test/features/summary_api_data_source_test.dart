import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:arah/features/networth/data/datasources/net_worth_remote_data_source.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/portfolio/data/datasources/portfolio_remote_data_source.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Response per path (sudah di-unwrap dari `{ data }`, seperti ApiClient.get).
class _FakeApi extends ApiClient {
  _FakeApi(this.responses)
    : super(baseUrl: 'http://test', tokenStorage: const TokenStorage(FlutterSecureStorage()));
  final Map<String, Object?> responses;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => responses[path];
}

// Potongan /api/summary asli dari fixture tahap B backend (doc/designapp/baseline/tahap-b).
final _summary = <String, dynamic>{
  'combinedNetWorth': 127396986.97,
  'totalAssetsAll': 132396986.97,
  'totalLiabilities': 5000000,
  'portfolioValueIDR': 60684750,
  'target': 1000000000,
  'healthScore': {
    'total': 63,
    'label': {'text': 'Baik'},
    'components': <dynamic>[],
  },
  'portfolioSummary': {'totalCostIDR': 62998250, 'unrealizedPnl': -2313500, 'count': 4},
  'manualAssets': [
    {
      'id': 'a1',
      'name': 'Kas',
      'category': 'cash',
      'currency': 'IDR',
      'value': 30000000,
      'valueIDR': 30000000,
    },
    {'id': 'a2', 'name': 'Dolar', 'category': 'cash', 'currency': 'USD', 'value': 1000, 'valueIDR': 18125000},
    {
      'id': 'a3',
      'name': 'Emas',
      'category': 'gold',
      'currency': 'GOLD',
      'value': 10,
      'valueIDR': 23587236.97,
    },
  ],
  'liabilityItems': [
    {'id': 'l1', 'name': 'Kartu kredit', 'category': 'credit_card', 'amountIDR': 5000000},
  ],
  'asOf': {'computedAt': '2026-10-29T07:36:41.453Z', 'usdToIdr': 18125},
};

void main() {
  test('beranda: angka dari /api/summary, briefing tanpa format Telegram', () async {
    final api = _FakeApi({
      '/api/summary': _summary,
      '/api/brief/today': {
        'date': '2026-10-29T00:00:00.000Z',
        'content': '☀️ *Selamat Pagi\\! — Kamis, 29 Okt 2026*\n\n📊 IHSG *\\+0\\.45%*\n_Pantau BBCA_',
      },
    });
    final s = await DashboardApiDataSource(api).fetchSummary();

    expect(s.netWorth, const Money.idr(127396986.97));
    expect(s.totalAssets, const Money.idr(132396986.97));
    expect(s.totalLiabilities, const Money.idr(5000000));
    expect(s.portfolioValue, const Money.idr(60684750));
    expect(s.healthScore, 63);
    expect(s.goalTarget, const Money.idr(1000000000));
    expect(s.asOf, DateTime.parse('2026-10-29T07:36:41.453Z'));
    expect(s.briefing!.date, DateTime.parse('2026-10-29T00:00:00.000Z'));
    expect(s.briefing!.summary, '📊 IHSG +0.45% · Pantau BBCA');
  });

  test('beranda: briefing & skor kesehatan boleh kosong', () async {
    final api = _FakeApi({
      '/api/summary': {..._summary, 'healthScore': null},
      '/api/brief/today': null,
    });
    final s = await DashboardApiDataSource(api).fetchSummary();
    expect(s.briefing, isNull);
    expect(s.healthScore, isNull);
  });

  test('kekayaan: item rupiah dari server, total sama dengan totalAssetsAll', () async {
    final api = _FakeApi({
      '/api/summary': _summary,
      '/api/settings': {
        'wealthTarget': 1000000000,
        'goalName': null,
        'goalDeadline': '2035-12-31T00:00:00.000Z',
        'goalReturnPct': 12,
        'goalMonthlyContrib': null,
      },
    });
    final nw = await NetWorthApiDataSource(api).fetchNetWorth();

    expect(nw.assets.map((a) => (a.name, a.category, a.value.amount, a.isAutomatic)), [
      ('Portofolio investasi', WealthCategory.portfolio, 60684750, true),
      ('Kas', WealthCategory.cash, 30000000, false),
      ('Dolar', WealthCategory.cash, 18125000, false),
      ('Emas', WealthCategory.gold, 23587236.97, false),
    ]);
    expect(nw.liabilities.single.category, WealthCategory.debt);
    expect(nw.totalAssets.amount, closeTo(132396986.97, 0.001));
    expect(nw.netWorth.amount, closeTo(127396986.97, 0.001));
    expect(nw.goal!.name, 'Target kekayaan');
    expect(nw.goal!.deadline, DateTime.parse('2035-12-31T00:00:00.000Z'));
    expect(nw.goal!.monthlyContribution, isNull);
    expect(nw.goal!.expectedReturnPercent, 12);
  });

  test('kekayaan: tanpa posisi tidak menampilkan baris portofolio Rp 0', () async {
    final api = _FakeApi({
      '/api/summary': {
        ..._summary,
        'portfolioValueIDR': 0,
        'portfolioSummary': {'totalCostIDR': 0, 'unrealizedPnl': 0, 'count': 0},
      },
      '/api/settings': {'wealthTarget': 100000000},
    });
    final nw = await NetWorthApiDataSource(api).fetchNetWorth();
    expect(nw.assets.any((a) => a.isAutomatic), isFalse);
  });

  test(
    'portofolio: posisi dari summary.positions, harga hilang tetap null, waktu harga paling lama',
    () async {
      final api = _FakeApi({
        '/api/summary': {
          ..._summary,
          // bentuk PortfolioWithCalc dari backend (src/lib/summary.ts enrichPortfolios)
          'positions': [
            {
              'id': 'p1',
              'stockCode': 'ZBASEA',
              'exchange': 'IDX',
              'currency': 'IDR',
              'lot': 10,
              'avgPrice': 9000,
              'platform': 'Stockbit',
              'sector': 'Keuangan',
              'marketPrice': 8500,
              'marketValue': 8500000,
              'priceFetchedAt': '2026-10-29T07:30:00.000Z',
            },
            {
              'id': 'p2',
              'stockCode': 'ZBASEB',
              'exchange': 'US',
              'currency': 'USD',
              'lot': 3,
              'avgPrice': 150,
              'platform': '',
              'sector': null,
              'marketPrice': 200,
              'marketValue': 600,
              'priceFetchedAt': '2026-10-29T07:12:00.000Z',
            },
            {
              'id': 'p3',
              'stockCode': 'ZZZZFAKE',
              'exchange': 'IDX',
              'currency': 'IDR',
              'lot': 5,
              'avgPrice': 1000,
              'platform': '',
              'sector': null,
              'marketPrice': null,
              'marketValue': null,
              'priceFetchedAt': null,
            },
          ],
        },
      });
      final portfolio = await PortfolioApiDataSource(api).fetchPortfolio();

      final [a, b, missing] = portfolio.positions;
      expect(
        (a.symbol, a.exchange, a.quantity, a.broker, a.sector),
        ('ZBASEA', Exchange.idx, 10, 'Stockbit', 'Keuangan'),
      );
      expect(a.lastPrice, const Money.idr(8500));
      // nilai pasar dihitung entity = marketValue server
      expect(a.marketValue, const Money.idr(8500000));
      expect(b.currency, Currency.usd);
      expect(b.marketValue, const Money.usd(600));
      expect(missing.lastPrice, isNull);
      expect(missing.marketValue, isNull);
      expect(portfolio.priceAsOf, DateTime.parse('2026-10-29T07:12:00.000Z'));
    },
  );
}
