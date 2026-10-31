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
    await tester.enterText(find.widgetWithText(TextFormField, 'Jumlah (lot untuk IDX, unit untuk US/Crypto)'), '3');
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

  testWidgets('target, pengaturan, panduan, surat investor, analisis, kalkulator (fixture)', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ArahApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'demo@arah.id');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    // Target kekayaan
    await tester.tap(find.text('Kekayaan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Target'));
    await tester.pumpAndSettle();
    // Tombol di bawah kartu target belum dibangun list sebelum digulir.
    await tester.drag(find.text('Tenggat'), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah target'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nominal target (Rp)'), '2000000000');
    await tapVisible(tester, find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Rp 2 M'), findsOneWidget); // progress target memakai format ringkas

    // Pengaturan: validasi chat ID lalu simpan
    await openFromMore(tester, 'Pengaturan');
    expect(find.text('demo@arah.id'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Telegram Chat ID'), 'abc');
    await tapVisible(tester, find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Chat ID hanya angka'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Telegram Chat ID'), '-1001234567890'); // chat grup
    await tapVisible(tester, find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan tersimpan'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openFromMore(tester, 'Panduan');
    expect(find.text('Mulai'), findsOneWidget);
    final helpList = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Drawdown'), 200, scrollable: helpList);
    await tester.drag(helpList, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drawdown'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dari titik tertinggi'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await openFromMore(tester, 'Surat investor');
    expect(find.text('Portofolio minggu ini'), findsOneWidget);
    expect(find.text('Posisi vs harga rata-rata beli'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Analisis risiko: tiga segmen + stress test kustom
    await openFromMore(tester, 'Analisis risiko');
    expect(find.text('Konsentrasi'), findsOneWidget);
    expect(find.textContaining('BBCA = 64,20%'), findsOneWidget);
    expect(find.text('Sharpe ratio'), findsOneWidget);
    expect(find.text('0,92'), findsOneWidget); // beta vs IHSG fixture
    expect(find.text('Beta vs BTC'), findsOneWidget);
    expect(find.text('0,18'), findsOneWidget);
    await tester.tap(find.text('Korelasi'));
    await tester.pumpAndSettle();
    expect(find.text('Searah'), findsOneWidget); // legenda heatmap
    expect(find.text('0.62'), findsNWidgets(2)); // sel BBCA×TLKM & TLKM×BBCA
    await tester.tap(find.text('Stress test'));
    await tester.pumpAndSettle();
    expect(find.text('Simulasi · Koreksi Ringan'), findsOneWidget);
    await tapVisible(tester, find.text('Kustom')); // chip terakhir di luar layar 360 px
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'IDX (%)'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Kalkulator: lot (biaya ikut dihitung → 1 lot dari Rp1 jt di Rp5.000)
    await openFromMore(tester, 'Kalkulator');
    await tapVisible(tester, find.text('Kalkulator lot'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Dana (Rp)'), '1000000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Harga per lembar (Rp)'), '5000');
    await tester.pumpAndSettle();
    expect(find.text('1 lot'), findsOneWidget);
    // Draft form pencatatan terisi dari hasil kalkulator, belum tersimpan.
    await tester.scrollUntilVisible(
      find.text('Gunakan pada form pencatatan'),
      200,
      // list halaman, bukan chip bursa yang juga bisa digulir mendatar
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
    );
    await tapVisible(tester, find.text('Gunakan pada form pencatatan'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan pencatatan'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '1'), findsOneWidget);
    final priceField = find.widgetWithText(TextFormField, 'Harga beli per lembar');
    expect(tester.widget<TextFormField>(priceField).controller!.text, '5000');
    Navigator.of(tester.element(find.text('Simpan pencatatan'))).pop(); // tutup sheet tanpa menyimpan
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    for (final (tool, expected) in [
      ('Position sizing', 'Isi harga entry dan stop loss; stop loss harus di bawah entry.'),
      ('BEP & averaging', 'Harga impas (BEP)'),
      ('Rebalancing', 'Aktual vs target'),
      ('Financial independence', 'FI number'),
      ('Biaya tersembunyi', 'Total per mata uang'),
      ('Wealth timeline', 'Nilai portofolio'),
    ]) {
      await tapVisible(tester, find.text(tool));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsWidgets, reason: tool);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
