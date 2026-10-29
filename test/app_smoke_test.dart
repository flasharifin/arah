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
}
