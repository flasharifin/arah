import 'package:arah/app/app.dart';
import 'package:arah/app/di.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/portfolio/data/datasources/portfolio_remote_data_source.dart';
import 'package:arah/features/portfolio/domain/entities/sale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test', tokenStorage: const TokenStorage(FlutterSecureStorage()));
  final posts = <(String, Object?)>[];

  @override
  Future<dynamic> post(String path, {Object? body}) async => posts.add((path, body));
}

class _FakePush implements PushNotificationService {
  @override
  Future<void> requestPermissionAndRegister() async {}
  @override
  Future<void> initialize() async {}
  @override
  Stream<String> get openedRoutes => const Stream.empty();
  @override
  Stream<void> get pushes => const Stream.empty();
  @override
  Future<bool> isPermissionGranted() async => true;
  @override
  Future<void> openNotificationSettings() async {}
  @override
  Future<void> unregisterDevice() async {}
}

PositionSale _sale({String id = 'bbca', double quantity = 40, String requestId = 'r1', String? note}) => PositionSale(
  positionId: id,
  quantity: quantity,
  price: 9500,
  date: DateTime.utc(2026, 11, 2),
  requestId: requestId,
  note: note,
);

void main() {
  test('API: body sesuai /api/portfolio/sell, catatan kosong tidak dikirim', () async {
    final api = _FakeApi();
    final source = PortfolioApiDataSource(api);
    await source.recordSale(_sale());
    await source.recordSale(_sale(note: 'ambil untung'));
    expect(api.posts[0].$1, '/api/portfolio/sell');
    expect(api.posts[0].$2, {
      'portfolioId': 'bbca',
      'lotSold': 40.0,
      'salePrice': 9500.0,
      'saleDate': '2026-11-02T00:00:00.000Z',
      'requestId': 'r1',
    });
    expect((api.posts[1].$2! as Map)['note'], 'ambil untung');
  });

  test('fixture: lot berkurang, rata-rata tetap, kirim ulang tidak dobel, habis → hilang', () async {
    final source = PortfolioFixtureDataSource();
    Future<double?> lot() async {
      final found = (await source.fetchPortfolio()).positions.where((p) => p.id == 'bbca');
      return found.isEmpty ? null : found.single.quantity;
    }

    final avg = (await source.fetchPortfolio()).positions.firstWhere((p) => p.id == 'bbca').avgPrice;
    await source.recordSale(_sale());
    await source.recordSale(_sale()); // kirim ulang
    expect(await lot(), 60);
    expect((await source.fetchPortfolio()).positions.firstWhere((p) => p.id == 'bbca').avgPrice, avg);

    await source.recordSale(_sale(quantity: 60, requestId: 'r2'));
    expect(await lot(), isNull);
  });

  testWidgets('dari detail: batas lot, jual sebagian, jual semua kembali ke daftar; dari tombol Catat bisa pilih posisi', (
    tester,
  ) async {
    // Tombol yang tertutup snackbar harus menggagalkan tes, bukan hanya peringatan.
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
    await initializeDateFormatting('id');
    FlutterSecureStorage.setMockInitialValues({});
    configureDependencies(useFixtures: true);
    sl
      ..unregister<PushNotificationService>()
      ..registerSingleton<PushNotificationService>(_FakePush());
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(360, 1400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ArahApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'demo@arah.id');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Portofolio').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('BBCA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catat penjualan'));
    await tester.pumpAndSettle();
    expect(find.text('Catat penjualan BBCA'), findsOneWidget);
    // Harga terisi dari harga terakhir.
    expect(find.widgetWithText(TextFormField, '9500'), findsOneWidget);

    final quantity = find.byType(TextFormField).first;
    await tester.enterText(quantity, '101');
    await tester.tap(find.text('Simpan penjualan'));
    await tester.pumpAndSettle();
    expect(find.text('Maksimal 100 lot'), findsOneWidget);

    await tester.enterText(quantity, '40');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan penjualan'));
    await tester.pumpAndSettle();
    expect(find.text('Penjualan tercatat'), findsOneWidget);
    expect(find.text('60 lot'), findsOneWidget); // masih di detail, jumlah berkurang

    // Langsung buka lagi saat snackbar masih tampil: pesan hilang, tombol Simpan bisa ditekan.
    await tester.tap(find.text('Catat penjualan'));
    await tester.pumpAndSettle();
    expect(find.text('Penjualan tercatat'), findsNothing);

    // Jual sebagian tadi tanpa dialog; jual semua minta konfirmasi, juga kalau angkanya diketik.
    await tester.enterText(find.byType(TextFormField).first, '60');
    await tester.tap(find.text('Simpan penjualan'));
    await tester.pumpAndSettle();
    expect(find.text('Jual semua BBCA?'), findsOneWidget);
    expect(find.textContaining('Seluruh 60 lot di Stockbit'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Catat penjualan BBCA'), findsOneWidget); // batal: form tetap terbuka, belum terjual

    await tester.tap(find.text('Jual semua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan penjualan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, jual semua'));
    await tester.pumpAndSettle();
    expect(find.text('Kepemilikan'), findsNothing); // kembali ke daftar
    expect(find.text('Posisi tidak ditemukan'), findsNothing);
    expect(find.text('BBCA'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Catat transaksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Penjualan'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih posisi yang dijual'), findsOneWidget);
    await tester.tap(find.text('TLKM').last); // yang pertama ada di daftar di belakang sheet
    await tester.pumpAndSettle();
    expect(find.text('Catat penjualan TLKM'), findsOneWidget);

    // Pembelian sama: snackbar tidak menutupi form yang baru dibuka.
    await tester.tapAt(const Offset(180, 10)); // tutup sheet
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Catat transaksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pembelian'));
    await tester.pumpAndSettle();
    expect(find.text('Catat pembelian'), findsWidgets);
    expect(find.text('Penjualan tercatat'), findsNothing);
  });
}
