import 'package:arah/app/app.dart';
import 'package:arah/app/di.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:fl_chart/fl_chart.dart';
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

    // Item baru di bawah daftar; gulir daftar aset seperti pengguna.
    Future<void> showDolar() => tester.scrollUntilVisible(
      find.text('Dolar'),
      100,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
    );

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
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await showDolar();
    expect(find.text('Rp 3.200.000'), findsOneWidget); // tile; hero sudah tergulir ke atas

    // Hapus
    await showDolar();
    await tester.tap(find.text('Dolar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus aset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Dolar'), findsNothing);

    // Snapshot — tab bar ikut tergulir (tidak di-pin); gulir kembali ke atas dulu.
    await tester.drag(find.byType(ListView).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada snapshot'), findsOneWidget);
    await tester.tap(find.text('Simpan snapshot sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Snapshot tersimpan'), findsOneWidget);
    expect(find.text('Rp 128.450.000'), findsWidgets); // snapshot (hero bisa tergulir)
    expect(find.text('Belum ada snapshot'), findsNothing);
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
    await tester.ensureVisible(find.text('Hapus akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus akun'));
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

    await tester.tap(find.text('AI Chat'));
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
