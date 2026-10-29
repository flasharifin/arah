import 'package:arah/app/app.dart';
import 'package:arah/app/di.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
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

  testWidgets('hapus akun: password salah ditolak, password benar kembali ke layar masuk (fixture)', (
    tester,
  ) async {
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

  testWidgets('lupa password: kirim kode, kode salah ditolak, kode benar lalu masuk lagi (fixture)', (
    tester,
  ) async {
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
}
