import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/portfolio/data/datasources/performance_remote_data_source.dart';
import 'package:arah/features/portfolio/domain/entities/performance.dart';
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

  test('API: pnl/daily minta 366 baris, Decimal string & benchmark null', () async {
    final api = _FakeApi({
      '/api/pnl/daily': [
        {
          'date': '2026-10-30T00:00:00.000Z',
          'portfolioValue': '100000000',
          'pnl': '-450000',
          'pnlPct': '-0.45',
          'ihsgChange': '0.3',
          'sp500Change': null,
        },
      ],
    });
    final rows = await PerformanceApiDataSource(api).fetchDaily();
    expect(api.queries['/api/pnl/daily'], {'limit': '366'});
    expect(rows.single.date, DateTime(2026, 10, 30));
    expect(rows.single.pnl, const Money.idr(-450000));
    expect(rows.single.pnlPercent, -0.45);
    expect(rows.single.ihsgChange, 0.3);
    expect(rows.single.sp500Change, isNull);
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
