import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/core/theme/app_theme.dart';
import 'package:arah/features/analysis/data/datasources/technical_rank_remote_data_source.dart';
import 'package:arah/features/analysis/data/repositories/technical_rank_repository_impl.dart';
import 'package:arah/features/analysis/domain/entities/technical_rank.dart';
import 'package:arah/features/analysis/domain/usecases/get_technical_ranking.dart';
import 'package:arah/features/analysis/presentation/bloc/technical_rank_cubit.dart';
import 'package:arah/features/analysis/presentation/pages/technical_rank_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FakeApi extends ApiClient {
  _FakeApi(this.response) : super(baseUrl: 'http://test', tokenStorage: const TokenStorage(FlutterSecureStorage()));
  final Object? response;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => response;
}

RankItem _item(
  String symbol,
  int score, {
  String trend = 'neutral',
  String cross = '—',
  double? rsi,
  bool surge = false,
  double? price,
  double? hi,
  double? lo,
}) => RankItem(
  symbol: symbol,
  exchange: 'IDX',
  inPortfolio: true,
  inWatchlist: false,
  score: score,
  label: 'x',
  emaTrend: trend,
  macdCross: cross,
  volumeSurge: surge,
  updatedAt: DateTime(2026, 10, 30),
  rsi: rsi,
  price: price,
  week52High: hi,
  week52Low: lo,
);

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  test('urutan: skor dulu, lalu tren/MACD/RSI/volume, lalu kode', () {
    final ranked = rankItems([
      _item('LOW', 2, trend: 'bullish', cross: 'bullish cross', rsi: 50),
      _item('HOT', 4, trend: 'bullish', rsi: 75), // jenuh beli → turun di antara skor 4
      _item('BEST', 4, trend: 'bullish', cross: 'bullish cross', rsi: 55, surge: true),
      _item('AAA', 3),
      _item('ZZZ', 3),
    ]);
    expect(ranked.map((i) => i.symbol), ['BEST', 'HOT', 'AAA', 'ZZZ', 'LOW']);
  });

  test('alasan: pendukung dulu, lalu netral, lalu peringatan', () {
    final reasons = rankReasons(_item('X', 4, trend: 'bullish', cross: 'bearish cross', rsi: 74, surge: true));
    expect(reasons.first.tone, ReasonTone.positive);
    expect(reasons.last.tone, ReasonTone.negative);
    expect(reasons.map((r) => r.text), contains('RSI 74 · jenuh beli, rawan koreksi'));
    expect(reasons.map((r) => r.text), contains('Volume melonjak di atas rata-rata'));
  });

  test('rentang 52 minggu: posisi harga 0–100, data kurang = null', () {
    expect(_item('X', 3, price: 1250, hi: 1300, lo: 800).week52Position, 90);
    expect(
      rankReasons(_item('X', 3, price: 1250, hi: 1300, lo: 800)).map((r) => r.text),
      contains('Dekat harga tertinggi 52 minggu'),
    );
    expect(_item('X', 3, price: 1000).week52Position, isNull);
  });

  test('API: kontrak /api/signals/ranking', () async {
    final api = _FakeApi({
      'items': [
        {
          'stockCode': 'ZRA',
          'exchange': 'IDX',
          'inPortfolio': true,
          'inWatchlist': true,
          'positionId': 'p1',
          'score': 4,
          'label': 'Sinyal Beli',
          'rsi': 58,
          'ema20': null,
          'ema50': null,
          'macdHist': null,
          'macdCross': 'bullish cross',
          'emaTrend': 'bullish',
          'volumeSurge': true,
          'fearGreed': null,
          'week52High': 1300,
          'week52Low': 800,
          'price': 1250,
          'updatedAt': '2026-10-31T01:00:00.000Z',
        },
      ],
      'missing': ['ZRD:IDX'],
    });
    final r = await TechnicalRankApiDataSource(api).fetch();
    expect(r.items.single.positionId, 'p1');
    expect(r.items.single.week52Position, 90);
    expect(r.missing, ['ZRD:IDX']);
  });

  testWidgets('halaman: urutan, nomor peringkat tetap saat difilter, ticker tanpa data', (tester) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => PrivacyCubit()),
          BlocProvider(
            create: (_) =>
                TechnicalRankCubit(GetTechnicalRanking(TechnicalRankRepositoryImpl(TechnicalRankFixtureDataSource())))
                  ..load(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const TechnicalRankPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // BBCA (tren naik + MACD naik + RSI sehat + volume) di atas AAPL (RSI jenuh beli) walau skor sama.
    final y = {
      for (final s in ['BBCA', 'AAPL', 'NVDA', 'TLKM']) s: tester.getTopLeft(find.text(s)).dy,
    };
    expect(y['BBCA']! < y['AAPL']! && y['AAPL']! < y['NVDA']! && y['NVDA']! < y['TLKM']!, isTrue);
    expect(find.text('#1'), findsOneWidget);
    expect(find.textContaining('Belum ada data teknikal: BTC'), findsOneWidget);

    await tester.ensureVisible(find.text('Watchlist 2')); // chip terakhir di bar yang bisa digulir
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watchlist 2'));
    await tester.pumpAndSettle();
    expect(find.text('BBCA'), findsNothing);
    expect(find.text('#3'), findsOneWidget); // NVDA tetap peringkat 3 dari semua saham
    expect(find.text('#4'), findsOneWidget); // TLKM
  });
}
