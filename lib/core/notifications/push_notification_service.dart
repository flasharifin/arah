import 'dart:async';

import 'package:arah/core/theme/app_colors.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Dipanggil FCM di isolate terpisah saat app di background atau tertutup.
/// Pesan dengan blok `notification` sudah ditampilkan sistem; di sini hanya pesan data-only.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.notification != null) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await PushNotificationService._initPlugin(plugin);
  await PushNotificationService._show(plugin, message);
}

/// FCM + notifikasi lokal.
///
/// Payload: blok `notification` (title/body) atau data-only `data.title`/`data.body`.
/// `data.route` (mis. `/portfolio/bbca`) dibuka saat notifikasi di-tap.
class PushNotificationService {
  final _local = FlutterLocalNotificationsPlugin();

  // Single-subscription: rute yang masuk sebelum app mendengarkan ditahan, tidak hilang.
  final _routes = StreamController<String>();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  static const _channel = AndroidNotificationChannel(
    'arah_default', // sama dengan default_notification_channel_id di AndroidManifest.xml
    'Notifikasi Arah',
    importance: Importance.high,
  );

  /// Rute dari notifikasi yang di-tap: dari FCM, notifikasi lokal, dan yang membuka app dari kondisi tertutup.
  Stream<String> get openedRoutes => _routes.stream;

  /// Dipanggil sekali di `main` setelah Firebase siap.
  Future<void> initialize() async {
    await _initPlugin(_local, onTap: (response) => _addRoute(response.payload));

    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) _addRoute(launch!.notificationResponse?.payload);
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _addRoute(initial.data['route']);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _addRoute(m.data['route']));

    // Sistem tidak menampilkan notifikasi FCM saat app terbuka; tampilkan sebagai notifikasi lokal.
    FirebaseMessaging.onMessage.listen((m) => _show(_local, m));
  }

  /// Minta izin notifikasi lalu daftarkan perangkat ke FCM.
  // shortcut: token dari `onRegistered` belum dikirim ke backend karena endpoint registrasi device belum ada; dengarkan stream itu saat endpoint tersedia.
  Future<void> requestPermissionAndRegister() async {
    final settings = await _fcm.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    try {
      await _fcm.register();
    } catch (_) {
      // Registrasi bisa gagal (mis. APNs belum siap di iOS); notifikasi tidak boleh membuat app gagal.
    }
  }

  void _addRoute(Object? route) {
    final safe = safeRoute(route);
    if (safe != null) _routes.add(safe);
  }

  /// Payload datang dari luar app: hanya rute internal yang diterima.
  static String? safeRoute(Object? route) =>
      route is String && route.startsWith('/') && !route.startsWith('//') ? route : null;

  /// Judul & isi dari blok `notification`, atau dari `data` untuk pesan data-only.
  static ({String? title, String? body}) contentOf(RemoteMessage message) => (
    title: message.notification?.title ?? message.data['title'] as String?,
    body: message.notification?.body ?? message.data['body'] as String?,
  );

  static Future<void> _initPlugin(
    FlutterLocalNotificationsPlugin plugin, {
    DidReceiveNotificationResponseCallback? onTap,
  }) async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_arah'),
        // Izin diminta lewat FCM setelah login, bukan saat inisialisasi.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: onTap,
    );
    await plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> _show(FlutterLocalNotificationsPlugin plugin, RemoteMessage message) async {
    final content = contentOf(message);
    if (content.title == null && content.body == null) return;
    await plugin.show(
      id: message.messageId.hashCode,
      title: content.title,
      body: content.body,
      payload: safeRoute(message.data['route']),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          importance: Importance.high,
          priority: Priority.high,
          color: AppColors.primary,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
