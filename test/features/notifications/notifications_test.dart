import 'package:arah/app/di.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:arah/core/state/privacy_cubit.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/core/theme/app_theme.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:arah/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:arah/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:arah/features/notifications/domain/entities/app_notification.dart';
import 'package:arah/features/notifications/domain/usecases/notification_usecases.dart';
import 'package:arah/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:arah/features/notifications/presentation/pages/notification_settings_page.dart';
import 'package:arah/features/notifications/presentation/pages/notifications_page.dart';
import 'package:arah/features/settings/data/datasources/settings_remote_data_source.dart';
import 'package:arah/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:arah/features/settings/domain/usecases/settings_usecases.dart';
import 'package:arah/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:arah/features/settings/presentation/pages/settings_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
  bool granted = true;
  int opened = 0;
  bool openFails = false;

  @override
  Future<bool> isPermissionGranted() async => granted;
  @override
  Future<void> openNotificationSettings() async {
    if (openFails) throw Exception('plugin belum terpasang');
    opened++;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

SettingsCubit settingsCubit(SettingsRemoteDataSource source) {
  final repository = SettingsRepositoryImpl(source);
  return SettingsCubit(get: GetSettings(repository), save: SaveSettings(repository));
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

    testWidgets('drawdown: ambang tampil, Ubah ambang membuka Pengaturan, nilai baru terbaca saat kembali', (tester) async {
      sl.allowReassignment = true;
      sl.registerSingleton<PushNotificationService>(_FakePush());
      addTearDown(sl.reset);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(800, 2400);
      addTearDown(tester.view.reset);
      final source = SettingsFixtureDataSource();
      final router = GoRouter(
        initialLocation: '/home/notifications/settings',
        routes: [
          GoRoute(
            path: '/home/notifications/settings',
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      NotificationPrefsCubit(get: GetNotificationPrefs(repo), save: SaveNotificationPrefs(repo))..load(),
                ),
                BlocProvider(create: (_) => settingsCubit(source)..load()),
              ],
              child: const NotificationSettingsPage(),
            ),
            routes: [
              GoRoute(
                path: 'account',
                builder: (_, _) => BlocProvider(create: (_) => settingsCubit(source)..load(), child: const SettingsPage()),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      final auth = _MockAuthBloc();
      whenListen(auth, const Stream<AuthState>.empty(), initialState: const AuthState(status: AuthStatus.authenticated));
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider(create: (_) => PrivacyCubit()),
          ],
          child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
      Future<void> settle() async {
        await tester.pump(const Duration(milliseconds: 400)); // jeda data contoh
        await tester.pumpAndSettle();
      }

      await settle();
      await settle(); // SettingsCubit dibuat saat baris drawdown pertama kali tampil
      expect(find.text('Saat porto turun 10% dari puncak'), findsOneWidget);

      await tester.tap(find.text('Ubah ambang'));
      await settle();
      expect(find.text('Pengaturan'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '7,5');
      await tester.tap(find.text('Simpan'));
      await settle();
      await tester.pageBack();
      await settle();
      expect(find.text('Saat porto turun 7,5% dari puncak'), findsOneWidget);
      // Ketuk tautan tidak boleh ikut mengubah saklarnya.
      final prefs = await GetNotificationPrefs(repo)(const NoParams());
      expect(prefs.fold((_) => null, (p) => p.isEnabled(NotificationType.drawdown)), isTrue);
    });

    testWidgets('pengaturan: ganti cara kirim dan saklar tersimpan, perkiraan berubah', (tester) async {
      sl.allowReassignment = true;
      final push = _FakePush();
      sl.registerSingleton<PushNotificationService>(push);
      addTearDown(sl.reset);
      // Layar tinggi supaya semua saklar terlihat tanpa menggulir.
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(800, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    NotificationPrefsCubit(get: GetNotificationPrefs(repo), save: SaveNotificationPrefs(repo))..load(),
              ),
              BlocProvider(create: (_) => settingsCubit(SettingsFixtureDataSource())..load()),
            ],
            child: const NotificationSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Izin notifikasi aktif'), findsOneWidget);
      await tester.tap(find.text('Buka'));
      expect(push.opened, 1);
      // Izin dimatikan di pengaturan HP → terbaca lagi saat kembali ke app.
      push.granted = false;
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Izin notifikasi mati'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('push maksimal di hari biasa, ditambah Penting kalau terjadi'), findsOneWidget);

      await tester.tap(find.text('Gabung jadi satu push pagi'));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('push gabungan pagi di hari biasa, ditambah Penting kalau terjadi'), findsOneWidget);
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

      // Gagal membuka pengaturan HP tidak boleh diam saja.
      push.openFails = true;
      await tester.tap(find.text('Buka'));
      await tester.pump();
      expect(find.textContaining('Arah → Notifikasi'), findsOneWidget);
    });
  });
}
