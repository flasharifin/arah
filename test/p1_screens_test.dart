import 'package:arah/app/app.dart';
import 'package:arah/app/di.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:arah/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Firebase tidak diinisialisasi di tes.
class _FakePush implements PushNotificationService {
  @override
  Future<void> requestPermissionAndRegister() async {}
  @override
  Future<void> initialize() async {}
  @override
  Stream<String> get openedRoutes => const Stream.empty();
  @override
  Future<void> unregisterDevice() async {}
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id');
    FlutterSecureStorage.setMockInitialValues({});
    configureDependencies(useFixtures: true);
    sl
      ..unregister<PushNotificationService>()
      ..registerSingleton<PushNotificationService>(_FakePush());
  });

  // Tombol di bawah sheet bisa berada di luar layar uji 360×800; gulir dulu seperti pengguna.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  Future<void> openFromMore(WidgetTester tester, String menu) async {
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(menu));
    await tester.pumpAndSettle();
  }

  testWidgets('watchlist, DCA, dividen, jurnal: aksi utama tiap layar (fixture)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ArahApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'demo@arah.id');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    // Watchlist: tambah BBRI
    await openFromMore(tester, 'Watchlist');
    expect(find.textContaining('TLKM'), findsOneWidget);
    await tester.tap(find.byTooltip('Tambah'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Kode saham'), 'bbri');
    await tester.enterText(find.widgetWithText(TextFormField, 'Harga target (opsional)'), '4500');
    await tapVisible(tester, find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('BBRI'), findsOneWidget);
    // sinyal & rentang 52 minggu dari data fixture TLKM
    expect(find.text('Sinyal Beli (4/5)'), findsOneWidget);
    expect(find.text('Rentang 52 minggu'), findsOneWidget);

    // Catat pembelian dari watchlist: kode terisi, tersimpan ke portofolio
    final tlkmCard = find.ancestor(of: find.textContaining('TLKM'), matching: find.byType(AppCard));
    final buyButton = find.descendant(of: tlkmCard, matching: find.text('Catat pembelian'));
    await tester.ensureVisible(buyButton);
    await tester.pumpAndSettle();
    await tester.tap(buyButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Lot (100 lembar)'), '5');
    await tester.enterText(find.widgetWithText(TextFormField, 'Harga beli per lembar'), '2900');
    await tester.pump();
    expect(find.text('Rp 1.450.000'), findsOneWidget); // pratinjau 5 × 100 × 2900
    await tester.ensureVisible(find.text('Simpan pencatatan'));
    await tester.tap(find.text('Simpan pencatatan'));
    await tester.pumpAndSettle();
    expect(find.text('Pembelian tercatat'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // SnackBar (4 dtk) hilang, tidak menutupi sheet berikutnya
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // DCA: catat pelaksanaan → muncul di Riwayat
    await openFromMore(tester, 'DCA');
    await tester.tap(find.text('Catat pelaksanaan'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Jumlah (lot untuk IDX, unit untuk US/Crypto)'),
      '3',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Harga beli'), '8900');
    await tapVisible(tester, find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('BBCA · 3 @ 8.900'), findsOneWidget);

    // DCA: rencana baru dari posisi yang ada → kartu rencana bertambah
    await tester.tap(find.text('Rencana'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tambah rencana'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Budget per periode'), '1000000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Target harga beli'), '8800');
    await tapVisible(tester, find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Catat pelaksanaan'), findsNWidgets(2));

    // DCA: simulasi menghitung harga rata-rata baru tanpa mencatat apa pun
    await tester.tap(find.text('Simulasi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Beli lagi (lot)'), '10');
    await tester.enterText(find.widgetWithText(TextFormField, 'Di harga'), '8000');
    await tester.pump();
    expect(find.text('Harga rata-rata baru'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Dividen: jadwal mendatang & total diterima tahun ini
    await openFromMore(tester, 'Dividen');
    expect(find.textContaining('270 per saham'), findsOneWidget);
    await tester.tap(find.byTooltip('Tambah dividen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Dividen per saham (DPS)'), '200');
    await tapVisible(tester, find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('200 per saham'), findsOneWidget); // tanpa tanggal bayar → Mendatang
    await tester.tap(find.text('Diterima'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Diterima tahun'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Jurnal: simpan catatan; perubahan belum disimpan memunculkan konfirmasi saat kembali
    await openFromMore(tester, 'Jurnal');
    await tester.enterText(find.byType(TextField).last, 'Pasar sepi hari ini');
    await tester.pump();
    expect(find.text('Belum disimpan'), findsOneWidget);
    await tapVisible(tester, find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Belum disimpan'), findsNothing);
    expect(find.text('Kontribusi hari ini'), findsOneWidget); // rincian per saham untuk hari ini

    // Kosongkan catatan lalu simpan → catatan dihapus
    await tester.enterText(find.byType(TextField).last, '');
    await tester.pump();
    expect(find.text('Belum disimpan · catatan akan dihapus saat disimpan'), findsOneWidget);
    await tapVisible(tester, find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Belum disimpan'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'Pasar sepi hari ini, lanjut besok');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Catatan belum disimpan'), findsOneWidget);
    await tester.tap(find.text('Buang'));
    await tester.pumpAndSettle();
    expect(find.text('Watchlist'), findsOneWidget); // kembali ke Lainnya
  });
}
