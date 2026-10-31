import 'package:arah/app/app.dart';
import 'package:arah/app/di.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('login lalu jelajahi kelima tab dan detail posisi (fixture)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ArahApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'demo@arah.id');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Ringkasan keuanganmu'), findsOneWidget);

    await tester.tap(find.text('Portofolio').last);
    await tester.pumpAndSettle();
    expect(find.text('BBCA'), findsOneWidget);

    await tester.tap(find.text('BBCA'));
    await tester.pumpAndSettle();
    expect(find.text('Kepemilikan'), findsOneWidget);

    await tester.ensureVisible(find.text('Tanyakan posisi ini ke AI'));
    await tester.tap(find.text('Tanyakan posisi ini ke AI'));
    await tester.pumpAndSettle();
    expect(find.text('Konteks: BBCA · IDX'), findsOneWidget);

    await tester.tap(find.byTooltip('Kirim'));
    await tester.pump(const Duration(seconds: 1)); // jeda balasan fixture
    await tester.pumpAndSettle();
    expect(find.textContaining('Ini jawaban contoh'), findsOneWidget);

    await tester.tap(find.text('Kekayaan'));
    await tester.pumpAndSettle();
    expect(find.text('Kekayaan bersih'), findsOneWidget);

    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    expect(find.text('Watchlist'), findsOneWidget);
  });

  testWidgets('portofolio: kinerja dengan grafik & periode, riwayat jual per mata uang (fixture)', (tester) async {
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

    await tester.tap(find.text('Portofolio').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kinerja'));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.textContaining('dalam 1B'), findsOneWidget);
    expect(find.textContaining('dari IHSG'), findsOneWidget);
    expect(find.textContaining('dari BTC'), findsOneWidget); // garis BTC ikut di ringkasan & legenda
    expect(find.text('BTC'), findsOneWidget); // label legenda

    await tester.tap(find.text('1T'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dalam 1T'), findsOneWidget);

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Realized PnL · 3 transaksi'), findsOneWidget);
    expect(find.text('Rupiah'), findsOneWidget);
    expect(find.text('Dolar AS'), findsOneWidget);

    await tester.tap(find.text('1B'));
    await tester.pumpAndSettle();
    expect(find.text('Realized PnL · 1 transaksi'), findsOneWidget);
    expect(find.text('Dolar AS'), findsNothing);
  });

  testWidgets('kekayaan: tambah aset USD, ubah, hapus, simpan snapshot (fixture)', (tester) async {
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

    await tester.tap(find.text('Kekayaan'));
    await tester.pumpAndSettle();
    expect(find.text('Rp 128.450.000'), findsOneWidget);

    // Modul Kekayaan bertumpuk dalam satu halaman; gulir ke item seperti pengguna.
    Future<void> showDolar() async {
      await tester.ensureVisible(find.text('Dolar'));
      await tester.pumpAndSettle();
    }

    // Tambah US$100 → fixture mengonversi 16.000/US$ → kekayaan bersih +1,6 jt
    await tester.tap(find.text('Tambah aset'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nama aset'), 'Dolar');
    await tester.tap(find.text('Rupiah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dolar AS').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nilai (US\$)'), '100');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Rp 130.050.000'), findsOneWidget);
    await showDolar();

    // Ubah jadi US$200
    await tester.tap(find.text('Dolar'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah aset'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Nilai (US\$)'), '200');
    await tester.enterText(find.widgetWithText(TextFormField, 'Catatan (opsional)'), 'Jenius');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await showDolar();
    expect(find.text('Rp 3.200.000'), findsOneWidget); // nilai item
    expect(find.text('Kas · Jenius'), findsOneWidget); // catatan tampil seperti di web

    // Hapus
    await showDolar();
    await tester.tap(find.text('Dolar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus aset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Dolar'), findsNothing);

    // Snapshot: tombol simpan di kepala kartu Riwayat (tidak perlu menggulir melewati daftar).
    await tester.ensureVisible(find.text('Riwayat kekayaan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Belum ada snapshot'), findsOneWidget);
    await tester.tap(find.text('Simpan snapshot'));
    await tester.pumpAndSettle();
    expect(find.text('Snapshot tersimpan'), findsOneWidget);
    expect(find.textContaining('Belum ada snapshot'), findsNothing);

    // 6 snapshot → tampil 5 terbaru + "Lihat semua"; filter periode tetap menampilkan yang baru disimpan.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Simpan snapshot'));
      await tester.pump(const Duration(seconds: 5)); // tunggu SnackBar hilang
      await tester.pumpAndSettle();
    }
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(5));
    await tester.ensureVisible(find.text('Lihat semua 6 snapshot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lihat semua 6 snapshot'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(6));
    await tester.ensureVisible(find.text('1T'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1T'));
    await tester.pumpAndSettle();
    expect(find.text('Lihat semua 6 snapshot'), findsOneWidget); // ganti periode kembali ke 5 terbaru
  });

  testWidgets('back di layar utama: konfirmasi tutup app; back di sub-halaman kembali biasa', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final platformCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(const ArahApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'demo@arah.id');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    // Pintasan Sinyal di Beranda: back kembali ke Beranda, bukan ke Lainnya.
    await tester.tap(find.text('Sinyal'));
    await tester.pumpAndSettle();
    expect(find.text('Peringkat teknikal'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Peringkat teknikal'), findsNothing);
    expect(find.text('Sinyal'), findsOneWidget);
    expect(find.text('Tutup Arah?'), findsNothing);

    for (final (shortcut, page) in [('Kinerja', 'Portofolio'), ('Jurnal', 'Jurnal')]) {
      await tester.tap(find.text(shortcut));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget, reason: '$page dibuka di atas Beranda');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Sinyal'), findsOneWidget, reason: 'back dari $shortcut kembali ke Beranda');
      expect(find.text('Tutup Arah?'), findsNothing);
    }

    // Sub-halaman: back kembali ke daftar, tanpa dialog.
    await tester.tap(find.text('Portofolio').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BBCA'));
    await tester.pumpAndSettle();
    expect(find.text('Kepemilikan'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Kepemilikan'), findsNothing);
    expect(find.text('Tutup Arah?'), findsNothing);

    // Layar utama: konfirmasi dulu; Batal tetap di app.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Tutup Arah?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Tutup Arah?'), findsNothing);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    // Tutup → app benar-benar ditutup.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(platformCalls, contains('SystemNavigator.pop'));
  });

  testWidgets('hapus akun: password salah ditolak, password benar kembali ke layar masuk (fixture)', (tester) async {
    FlutterSecureStorage.setMockInitialValues({}); // token dari tes sebelumnya membuat app langsung login
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ArahApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'demo@arah.id');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hapus akun dan semua data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus akun dan semua data'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus akun permanen?'), findsOneWidget);

    // Fixture: password < 8 karakter dianggap salah.
    final dialogField = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField));
    await tester.enterText(dialogField, 'salah');
    await tester.tap(find.text('Hapus permanen'));
    await tester.pumpAndSettle();
    expect(find.text('Password salah'), findsOneWidget);
    expect(find.text('Hapus akun permanen?'), findsOneWidget);

    await tester.enterText(dialogField, 'password123');
    await tester.tap(find.text('Hapus permanen'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus akun permanen?'), findsNothing);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('lupa password: kirim kode, kode salah ditolak, kode benar lalu masuk lagi (fixture)', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ArahApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lupa password?'));
    await tester.pumpAndSettle();
    expect(find.text('Lupa password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'demo@arah.id');
    await tester.tap(find.text('Kirim kode'));
    await tester.pumpAndSettle();
    expect(find.textContaining('demo@arah.id'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '000000');
    await tester.enterText(fields.at(1), 'baru-123');
    await tester.enterText(fields.at(2), 'baru-123');
    await tester.tap(find.text('Simpan password baru'));
    await tester.pumpAndSettle();
    expect(find.text('Kode salah atau sudah kedaluwarsa'), findsOneWidget);

    // Fixture: kode yang benar 123456.
    await tester.enterText(fields.at(0), '123456');
    await tester.tap(find.text('Simpan password baru'));
    await tester.pumpAndSettle();
    expect(find.text('Password sudah diganti'), findsOneWidget);

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Lupa password?'), findsOneWidget);
  });

  testWidgets('riwayat chat: ubah nama, buka percakapan lama, hapus (fixture)', (tester) async {
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

    await tester.tap(find.text('Tanya AI')); // AI Chat dibuka dari header Beranda
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Pertanyaan untuk riwayat');
    await tester.tap(find.byTooltip('Kirim'));
    await tester.pump(const Duration(seconds: 1)); // jeda balasan fixture
    await tester.pumpAndSettle();
    // Chat baru → layar kosong, lalu buka percakapan tadi dari riwayat.
    await tester.tap(find.byTooltip('Chat baru'));
    await tester.pumpAndSettle();
    expect(find.text('Pertanyaan untuk riwayat'), findsNothing);

    await tester.tap(find.byTooltip('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Hari ini'), findsOneWidget);
    Finder tileOf(String title) => find.ancestor(of: find.text(title), matching: find.byType(ListTile));

    await tester.tap(
      find.descendant(of: tileOf('Pertanyaan untuk riwayat'), matching: find.byTooltip('Opsi percakapan')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah nama'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
      'Judul baru',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Judul baru'), findsOneWidget);

    await tester.tap(find.text('Judul baru'));
    await tester.pumpAndSettle();
    expect(find.text('Pertanyaan untuk riwayat'), findsOneWidget); // pesan lama tampil di layar chat

    await tester.tap(find.byTooltip('Riwayat'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: tileOf('Judul baru'), matching: find.byTooltip('Opsi percakapan')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus percakapan?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Hapus')));
    await tester.pumpAndSettle();
    expect(find.text('Judul baru'), findsNothing);

    // Percakapan yang sedang terbuka dihapus → layar chat kosong lagi.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Pertanyaan untuk riwayat'), findsNothing);
    expect(find.text('Apa yang ingin kamu pahami hari ini?'), findsOneWidget);
  });
}
