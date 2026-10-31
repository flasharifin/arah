import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/analysis/data/datasources/analysis_remote_data_source.dart';
import 'package:arah/features/analysis/domain/entities/risk_analysis.dart';
import 'package:arah/features/calculator/data/datasources/insights_remote_data_source.dart';
import 'package:arah/features/letter/data/datasources/letter_remote_data_source.dart';
import 'package:arah/features/networth/data/datasources/net_worth_remote_data_source.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/settings/data/datasources/settings_remote_data_source.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// GET mengembalikan [responses] (sudah di-unwrap `{ data }`); PUT direkam dan membalas [putReply].
class _FakeApi extends ApiClient {
  _FakeApi([this.responses = const {}, this.putReply])
    : super(baseUrl: 'http://test', tokenStorage: const TokenStorage(FlutterSecureStorage()));
  final Map<String, Object?> responses;
  final Object? putReply;
  final puts = <(String, Object?)>[];

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => responses[path];

  @override
  Future<dynamic> put(String path, {Object? body}) async {
    puts.add((path, body));
    return putReply;
  }
}

void main() {
  test('target: semua field dikirim, tenggat YYYY-MM-DD, kosong = null', () async {
    final api = _FakeApi();
    await NetWorthApiDataSource(
      api,
    ).saveGoal(WealthGoal(name: ' Rumah ', target: const Money.idr(2e9), deadline: DateTime(2030, 6, 30)));
    expect(api.puts.single.$1, '/api/settings');
    expect(api.puts.single.$2, {
      'goalName': 'Rumah',
      'wealthTarget': 2e9,
      'goalDeadline': '2030-06-30',
      'goalMonthlyContrib': null,
      'goalReturnPct': null,
    });
  });

  test('pengaturan: chat ID kosong dikirim "" (server mengosongkan), balasan server dipakai', () async {
    final api = _FakeApi(const {}, {'wealthTarget': 1e9, 'drawdownThreshold': 15, 'telegramChatId': null});
    final s = await SettingsApiDataSource(api).save(telegramChatId: null, drawdownThreshold: 15);
    expect(api.puts.single.$2, {'telegramChatId': '', 'drawdownThreshold': 15.0});
    expect(s.drawdownThreshold, 15);
    expect(s.telegramChatId, isNull);
  });

  test('analisis: kontrak /api/analysis/risk, volatilitas null = data kurang', () async {
    final api = _FakeApi({
      '/api/analysis/risk': {
        'positions': [
          {
            'stockCode': 'BBCA',
            'exchange': 'IDX',
            'valueIDR': 9e6,
            'weight': 60,
            'hasPrice': true,
            'volatility': 18.2,
            'maxDrawdown': 5,
          },
          {
            'stockCode': 'BTC',
            'exchange': 'CRYPTO',
            'valueIDR': 6e6,
            'weight': 40,
            'hasPrice': false,
            'volatility': null,
            'maxDrawdown': null,
          },
        ],
        'totalValueIDR': 15e6,
        'correlations': [
          {'a': 'BBCA:IDX', 'b': 'BTC:CRYPTO', 'r': null},
        ],
        'scenarios': [
          {
            'id': 'mild',
            'label': 'Koreksi Ringan',
            'desc': 'Koreksi normal pasar',
            'IDX': -10,
            'US': -8,
            'CRYPTO': -15,
          },
        ],
        'historyDays': 0,
        'portfolio': {
          'sharpe': null,
          'riskFreePct': 6,
          'betaIhsg': 1.2,
          'betaSp500': null,
          'betaBtc': 0.4,
          'days': 25,
          'ihsgDays': 25,
          'sp500Days': 0,
        },
        'asOf': {'computedAt': '2026-10-31T00:00:00.000Z', 'usdToIdr': 16000},
      },
    });
    final a = await AnalysisApiDataSource(api).fetch();
    expect(a.portfolio, const PortfolioRisk(riskFreePercent: 6, days: 25, betaIhsg: 1.2, betaBtc: 0.4));
    expect(a.largest!.symbol, 'BBCA');
    expect(a.positions.last.volatility, isNull);
    expect(a.correlations.single.r, isNull);
    expect(a.scenarios.single.drops, (idx: -10.0, us: -8.0, crypto: -15.0));
  });

  test('stress test: nilai × (1 + penurunan bursa)', () {
    const positions = [
      RiskPosition(symbol: 'A', exchange: 'IDX', value: Money.idr(100), weight: 50, hasPrice: true),
      RiskPosition(symbol: 'B', exchange: 'US', value: Money.idr(100), weight: 50, hasPrice: true),
    ];
    final r = stressImpact(positions, (idx: -10, us: -20, crypto: 0));
    expect(r.before, const Money.idr(200));
    expect(r.after, const Money.idr(170));
    expect(r.rows.map((x) => x.delta.amount), [-10, -20]);
  });

  test('biaya tersembunyi: nominal dalam mata uang posisi (bukan IDR)', () async {
    final api = _FakeApi({
      '/api/portfolio/invisible-cost': {
        'positions': [
          {
            'stockCode': 'AAPL',
            'exchange': 'US',
            'currency': 'USD',
            'costBasis': 340,
            'holdDays': 90,
            'actualReturnPct': 5,
            'ihsgReturnPct': 1,
            'diffPct': 4,
            'isUnderperforming': false,
            'ocIDR': 0,
            'inflationIDR': 2.93,
            'totalInvisibleIDR': 2.93,
            'isZombie': false,
          },
        ],
        'summary': {'totalInvisibleCostIDR': 2.93},
      },
    });
    final c = (await InsightsApiDataSource(api).invisibleCost()).single;
    expect(c.total, const Money.usd(2.93));
  });

  test('surat investor: penjualan per mata uang, tanpa total campuran', () async {
    final api = _FakeApi({
      '/api/investor-letter': {
        'weekStart': '2026-10-24',
        'weekEnd': '2026-10-31',
        'currentPortfolioValue': 98450000,
        'weeklyChangePct': 1.3,
        'weeklyChangeIDR': 1250000,
        'ihsgWeeklyPct': 0.8,
        'sp500WeeklyPct': 1.5,
        'weekHighValue': 98900000,
        'weekLowValue': 96800000,
        'topGainers': [
          {'stockCode': 'AAPL', 'exchange': 'US', 'pct': 7.6},
        ],
        'topLosers': <dynamic>[],
        'salesThisWeek': [
          {'stockCode': 'NVDA', 'realizedPnl': -31.4, 'currency': 'USD', 'date': '2026-10-29'},
        ],
        'dividendsThisWeek': [
          {'stockCode': 'BBCA', 'receivedAmount': 270000, 'date': null},
        ],
        'totalRealizedThisWeek': -31,
        'positionCount': 4,
      },
    });
    final l = await LetterApiDataSource(api).fetch();
    expect(l.sales.single.realizedPnl, const Money.usd(-31.4));
    expect(l.dividends.single.date, isNull);
    expect(l.weekEnd, DateTime(2026, 10, 31));
  });
}
