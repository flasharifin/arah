import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/portfolio/data/datasources/portfolio_remote_data_source.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/domain/entities/purchase.dart';
import 'package:arah/features/watchlist/data/datasources/watchlist_remote_data_source.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends ApiClient {
  _FakeApi([this.getResponse])
    : super(baseUrl: 'http://test', tokenStorage: const TokenStorage(FlutterSecureStorage()));
  final Object? getResponse;
  final posts = <(String, Object?)>[];

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => getResponse;
  @override
  Future<dynamic> post(String path, {Object? body}) async => posts.add((path, body));
}

PositionPurchase _purchase({String requestId = 'req-1', double quantity = 10, double price = 8000}) =>
    PositionPurchase(
      symbol: ' bbca ',
      exchange: Exchange.idx,
      broker: 'Stockbit',
      quantity: quantity,
      price: price,
      date: DateTime.utc(2026, 10, 30),
      requestId: requestId,
    );

void main() {
  test('watchlist: sinyal & rentang 52 minggu dipetakan; tanpa sinyal → null', () async {
    final api = _FakeApi([
      {
        'id': 'w1',
        'stockCode': 'TLKM',
        'exchange': 'IDX',
        'currency': 'IDR',
        'status': 'observasi',
        'targetPrice': null,
        'lastPrice': 2950,
        'gapPct': null,
        'signal': {
          'rsi': 41.5,
          'emaTrend': 'bullish',
          'score': 4,
          'label': 'Sinyal Beli',
          'week52High': 4250,
          'week52Low': 2650,
          'week52Pos': 18.75,
        },
      },
      {
        'id': 'w2',
        'stockCode': 'NVDA',
        'exchange': 'US',
        'currency': 'USD',
        'status': 'skip',
        'signal': null,
      },
    ]);
    final [tlkm, nvda] = await WatchlistApiDataSource(api).list();
    final s = tlkm.signal!;
    expect(
      (s.score, s.label, s.rsi, s.trend, s.week52Low, s.week52High, s.week52Position),
      (4, 'Sinyal Beli', 41.5, 'bullish', 2650.0, 4250.0, 18.75),
    );
    expect(nvda.signal, isNull);
  });

  test(
    'catat pembelian: body POST /api/portfolio (kode dirapikan, mata uang dari bursa, requestId)',
    () async {
      final api = _FakeApi();
      await PortfolioApiDataSource(api).recordPurchase(_purchase());
      expect(api.posts.single.$1, '/api/portfolio');
      expect(api.posts.single.$2, {
        'stockCode': 'BBCA',
        'exchange': 'IDX',
        'currency': 'IDR',
        'platform': 'Stockbit',
        'lot': 10.0,
        'avgPrice': 8000.0,
        'purchaseDate': '2026-10-30T00:00:00.000Z',
        'sector': null,
        'note': null,
        'requestId': 'req-1',
      });
      expect(_purchase().total, 8000000); // 10 lot × 100 lembar × 8000
    },
  );

  test(
    'fixture: kode+broker sama → lot dijumlah & rata-rata tertimbang; requestId sama tidak dobel',
    () async {
      final source = PortfolioFixtureDataSource();
      await source.recordPurchase(_purchase());
      await source.recordPurchase(_purchase()); // kirim ulang
      final bbca = (await source.fetchPortfolio()).positions.firstWhere((p) => p.symbol == 'BBCA');
      expect(bbca.quantity, 110);
      expect(bbca.avgPrice.amount, closeTo(980000 / 110, 1e-9)); // (100×9000 + 10×8000)/110
      expect(bbca.avgPrice.currency, Currency.idr);
    },
  );
}
