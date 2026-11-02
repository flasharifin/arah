import 'package:arah/app/di.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/core/theme/app_theme.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:arah/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:arah/features/notifications/domain/entities/app_notification.dart';
import 'package:arah/features/notifications/domain/usecases/notification_usecases.dart';
import 'package:arah/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:arah/features/notifications/presentation/pages/notification_settings_page.dart';
import 'package:arah/features/notifications/presentation/pages/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FakeApi extends ApiClient {
  _FakeApi(this.response) : super(baseUrl: 'http://test', tokenStorage: const TokenStorage(FlutterSecureStorage()));
  final Object? response;
  final writes = <(String, String, Object?)>[];

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => response;
  @override
  Future<dynamic> patch(String path, {Object? body}) async => writes.add(('PATCH', path, body));
  @override
  Future<dynamic> put(String path, {Object? body}) async => writes.add(('PUT', path, body));
}

class _FakePush implements PushNotificationService {
  @override
  Future<bool> isPermissionGranted() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  group('preferensi', () {
    test('perkiraan push harian mengikuti cara kirim dan saklar', () {
      const all = NotificationPrefs();
      expect(all.maxDailyPushes, 5); // briefing + ringkasan + 3 sinyal
      expect(all.withType(NotificationType.signals, enabled: false).maxDailyPushes, 2);
      expect(all.copyWith(mode: NotificationMode.combined).maxDailyPushes, 1);
      const noDaily = NotificationPrefs(
        mode: NotificationMode.combined,
        disabled: {NotificationType.briefing, NotificationType.dailySummary, NotificationType.signals},
      );
      expect(noDaily.maxDailyPushes, 0);
      // Mengubah satu pengaturan tidak boleh mereset yang lain.
      const held = NotificationPrefs(holdNight: true);
      expect(held.copyWith(mode: NotificationMode.combined).holdNight, isTrue);
      expect(held.withType(NotificationType.signals, enabled: false).holdNight, isTrue);
      // Jenis penting tidak dihitung sebagai push rutin.
      expect(all.withType(NotificationType.priceAlert, enabled: false).maxDailyPushes, 5);
    });

    test('kode jenis dan cara kirim sama dengan backend; kode asing tidak merusak', () {
      expect(NotificationType.values.map((t) => t.code).toSet(), {
        'price_alert', 'drawdown', 'milestone', 'briefing', 'daily_summary', 'signals', 'weekly', 'periodic', 'dca',
      });
      expect(NotificationType.fromCode('baru'), NotificationType.periodic);
      expect(NotificationMode.fromCode('combined'), NotificationMode.combined);
      expect(NotificationMode.fromCode(null), NotificationMode.separate);
    });
  });

  group('API', () {
    test('daftar dipetakan: readAt → sudah dibaca, jenis asing → tetap tampil', () async {
      final api = _FakeApi([
        {'id': 'a', 'type': 'price_alert', 'title': 'T', 'body': 'B', 'route': '/portfolio', 'readAt': null, 'createdAt': '2026-11-02T01:00:00.000Z'},
        {'id': 'b', 'type': 'lain', 'title': 'T', 'body': 'B', 'route': null, 'readAt': '2026-11-02T02:00:00.000Z', 'createdAt': '2026-11-02T01:00:00.000Z'},
      ]);
      final items = await NotificationApiDataSource(api).list();
      expect(items[0].type, NotificationType.priceAlert);
      expect(items[0].isRead, isFalse);
      expect(items[0].route, '/portfolio');
      expect(items[1].isRead, isTrue);
      expect(items[1].route, isNull);
    });

    test('tandai dibaca dan simpan preferensi memakai kontrak backend', () async {
      final api = _FakeApi(null);
      final source = NotificationApiDataSource(api);
      await source.markRead('a');
      await source.markRead(null);
      await source.savePrefs(const NotificationPrefs(mode: NotificationMode.combined, disabled: {NotificationType.dailySummary}));
      expect((api.writes[0].$1, api.writes[0].$2), ('PATCH', '/api/mobile/notifications'));
      expect(api.writes[0].$3, {'id': 'a'});
      expect(api.writes[1].$3, {'all': true});
      expect((api.writes[2].$1, api.writes[2].$2), ('PUT', '/api/mobile/notifications/preferences'));
      expect(api.writes[2].$3, {'mode': 'combined', 'disabledTypes': ['daily_summary'], 'holdNight': false});
    });

    test('preferensi dari server: jenis asing diabaikan', () async {
      final prefs = await NotificationApiDataSource(_FakeApi({'mode': 'combined', 'disabledTypes': ['signals', 'lain'], 'holdNight': true})).getPrefs();
      expect(prefs.mode, NotificationMode.combined);
      expect(prefs.disabled, {NotificationType.signals});
      expect(prefs.holdNight, isTrue);
    });
  });

  group('layar', () {
    late NotificationRepositoryImpl repo;
    late UnreadNotificationsCubit unread;

    setUp(() {
      repo = NotificationRepositoryImpl(NotificationFixtureDataSource());
      unread = UnreadNotificationsCubit(get: GetUnreadNotificationCount(repo), pushes: const Stream.empty());
    });

    Future<void> pumpList(WidgetTester tester) async {
      await unread.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: unread),
              BlocProvider(create: (_) => NotificationsCubit(get: GetNotifications(repo), mark: MarkNotificationRead(repo))..load()),
            ],
            child: const NotificationsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('filter, buka isi lengkap menandai dibaca, lalu tandai semua', (tester) async {
      await pumpList(tester);
      expect(find.text('2 belum dibaca'), findsOneWidget);
      expect(unread.state, 2);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Penting'));
      await tester.pumpAndSettle();
      expect(find.text('Selamat Pagi!'), findsNothing);
      expect(find.text('Price Alert Terpenuhi!'), findsOneWidget);

      await tester.tap(find.text('Price Alert Terpenuhi!'));
      await tester.pumpAndSettle();
      expect(find.text('BBRI menyentuh target Rp 4.500'), findsOneWidget);
      expect(unread.state, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
      await tester.pumpAndSettle();
      expect(find.text('1 belum dibaca'), findsOneWidget);
      await tester.tap(find.text('Tandai semua dibaca'));
      await tester.pumpAndSettle();
      expect(find.text('Semua sudah dibaca'), findsOneWidget);
      expect(unread.state, 0);
    });

    testWidgets('pengaturan: ganti cara kirim dan saklar tersimpan, perkiraan berubah', (tester) async {
      sl.allowReassignment = true;
      sl.registerSingleton<PushNotificationService>(_FakePush());
      addTearDown(sl.reset);
      // Layar tinggi supaya semua saklar terlihat tanpa menggulir.
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(800, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider(
            create: (_) => NotificationPrefsCubit(get: GetNotificationPrefs(repo), save: SaveNotificationPrefs(repo))..load(),
            child: const NotificationSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Izin notifikasi aktif'), findsOneWidget);
      expect(find.textContaining('Maksimal 5 push'), findsOneWidget);

      await tester.tap(find.text('Gabung jadi satu push pagi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Maksimal 1 push'), findsOneWidget);
      final saved = await GetNotificationPrefs(repo)(const NoParams());
      expect(saved.fold((_) => null, (p) => p.mode), NotificationMode.combined);

      await tester.tap(find.text('Tahan push tengah malam'));
      await tester.pumpAndSettle();
      final held = await GetNotificationPrefs(repo)(const NoParams());
      expect(held.fold((_) => null, (p) => p.holdNight), isTrue);

      await tester.tap(find.text('Sinyal teknikal'));
      await tester.pumpAndSettle();
      final after = await GetNotificationPrefs(repo)(const NoParams());
      expect(after.fold((_) => null, (p) => p.disabled), {NotificationType.signals});
    });
  });
}
