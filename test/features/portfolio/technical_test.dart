import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/core/theme/app_theme.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/portfolio/data/datasources/technical_remote_data_source.dart';
import 'package:arah/features/portfolio/domain/entities/technical.dart';
import 'package:arah/features/portfolio/domain/repositories/technical_repository.dart';
import 'package:arah/features/portfolio/domain/usecases/get_technical.dart';
import 'package:arah/features/portfolio/data/repositories/technical_repository_impl.dart';
import 'package:arah/features/portfolio/presentation/bloc/technical_cubit.dart';
import 'package:arah/features/portfolio/presentation/widgets/technical_section.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FakeApi extends ApiClient {
  _FakeApi(this.response) : super(baseUrl: 'http://test', tokenStorage: const TokenStorage(FlutterSecureStorage()));
  final Object? response;
  String? path;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    this.path = path;
    return response;
  }
}

class _Repo implements TechnicalRepository {
  _Repo(this.ta);
  final TechnicalAnalysis ta;
  @override
  Future<Result<TechnicalAnalysis>> get(String positionId) async => Success(ta);
}

TaPoint _p({
  double close = 100,
  double? e20,
  double? e50,
  double? rsi,
  double? hist,
  double vol = 100,
  double? volMa,
  double? atr,
}) => TaPoint(
  date: DateTime(2026, 10, 30),
  close: close,
  volume: vol,
  ema20: e20,
  ema50: e50,
  rsi: rsi,
  macdHist: hist,
  volumeMa20: volMa,
  atr: atr,
);

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  test('tren EMA: aturan sama dengan backend (harga > EMA20 > EMA50 = naik)', () {
    expect(trendReading(_p(close: 110, e20: 105, e50: 100))!.tone, TaTone.positive);
    expect(trendReading(_p(close: 90, e20: 95, e50: 100))!.tone, TaTone.negative);
    expect(trendReading(_p(close: 102, e20: 105, e50: 100))!.tone, TaTone.neutral);
    expect(trendReading(_p(e20: 1)), isNull); // EMA50 belum terisi
  });

  test('RSI, MACD, volume: batas & arti', () {
    expect(rsiReading(_p(rsi: 25))!.meaning, startsWith('Jenuh jual'));
    expect(rsiReading(_p(rsi: 75))!.meaning, startsWith('Jenuh beli'));
    expect(rsiReading(_p(rsi: 50))!.meaning, 'Netral (30–70)');
    final signal = TaSignal(
      score: 4,
      label: 'Sinyal Beli',
      emaTrend: 'bullish',
      macdCross: 'bullish cross',
      volumeSurge: false,
      updatedAt: DateTime(2026),
    );
    expect(macdReading(_p(hist: 0.5), signal)!.meaning, 'Momentum menguat · baru persilangan naik');
    expect(macdReading(_p(hist: -0.5), null)!.tone, TaTone.negative);
    expect(volumeReading(_p(vol: 200, volMa: 100))!.value, '2,0× rata-rata 20 hari');
    expect(volumeReading(_p(vol: 50, volMa: 100))!.meaning, startsWith('Volume sepi'));
  });

  test('volatilitas ATR & posisimu: arti dan patokan stop', () {
    final v = volatilityReading(_p(close: 10000, atr: 250))!;
    expect(v.value, '±2,5%/hari');
    expect(v.meaning, contains('2×ATR di bawah harga: 9.500'));
    expect(volatilityReading(_p()), isNull);
    final up = _p(close: 110, e20: 105, e50: 100), down = _p(close: 90, e20: 95, e50: 100);
    expect(positionReading(-12, down)!.meaning, startsWith('Rugi dan tren masih turun'));
    expect(positionReading(-12, down)!.value, '−12,00%');
    expect(positionReading(8, up)!.tone, TaTone.positive);
    expect(positionReading(8, down)!.tone, TaTone.negative);
    expect(positionReading(null, up), isNull);
  });

  test('API: priceHistory & signal dari /api/portfolio/[id]/detail', () async {
    final api = _FakeApi({
      'priceHistory': [
        {
          'date': '2026-10-30',
          'close': 9500,
          'volume': 1200000,
          'ema20': 9400.5,
          'ema50': null,
          'rsi': 55.2,
          'macdHist': -2.1,
          'volumeMA20': 1000000,
          'atr': 120.5,
          'score': 4,
        },
      ],
      'signal': {
        'score': 2,
        'label': 'Sinyal Jual',
        'emaTrend': 'bearish',
        'macdCross': '—',
        'volumeSurge': true,
        'fearGreed': null,
        'updatedAt': '2026-10-30T01:00:00.000Z',
      },
    });
    final ta = await TechnicalApiDataSource(api).fetch('pos-1');
    expect(api.path, '/api/portfolio/pos-1/detail');
    expect(ta.points.single.ema50, isNull);
    expect(ta.points.single.volumeMa20, 1000000);
    expect(ta.points.single.atr, 120.5);
    expect(ta.points.single.score, 4);
    expect(ta.signal!.score, 2);
    expect(ta.signal!.volumeSurge, isTrue);
  });

  Future<void> pump(WidgetTester tester, TechnicalCubit cubit) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => PrivacyCubit()),
          BlocProvider.value(value: cubit),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(padding: EdgeInsets.all(20), child: TechnicalSection(pnlPercent: -5)),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('bagian teknikal: sinyal, 2 grafik, bacaan indikator, ganti periode', (tester) async {
    final cubit = TechnicalCubit(GetTechnical(TechnicalRepositoryImpl(TechnicalFixtureDataSource())), 'bbca')..load();
    await pump(tester, cubit);
    expect(tester.takeException(), isNull);
    expect(find.text('Sinyal Beli'), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
    expect(find.byType(LineChart), findsNWidgets(3)); // harga, riwayat skor, RSI
    expect(find.text('Riwayat skor (1–5)'), findsOneWidget);
    expect(find.text('Posisimu'), findsOneWidget);
    expect(find.text('Volatilitas (ATR 14)'), findsOneWidget);
    expect(find.text('Bacaan indikator'), findsOneWidget);
    expect(find.text('RSI (14)'), findsWidgets);
    await tester.tap(find.text('1T'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('data kurang → penjelasan, bukan grafik kosong', (tester) async {
    final cubit = TechnicalCubit(GetTechnical(_Repo(const TechnicalAnalysis(points: []))), 'x')..load();
    await pump(tester, cubit);
    expect(find.textContaining('Data teknikal belum cukup'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });
}
