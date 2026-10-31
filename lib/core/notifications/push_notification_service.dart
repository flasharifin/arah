import 'dart:async';
import 'dart:io';

import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/theme/app_colors.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:flutter/foundation.dart';
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
  /// [api] null = mode fixture: perangkat tidak didaftarkan ke backend.
  PushNotificationService({ApiClient? api}) : _api = api;

  final ApiClient? _api;
  final _local = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _registered;
  String? _fid;

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

  /// Minta izin notifikasi lalu daftarkan perangkat ke FCM dan backend (`PUT /api/mobile/devices`).
  /// Dipanggil setiap sesi login aktif (login & app dibuka dengan sesi tersimpan).
  Future<void> requestPermissionAndRegister() async {
    final settings = await _fcm.requestPermission();
    debugPrint('[push] izin: ${settings.authorizationStatus.name}');
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    _registered ??= _fcm.onRegistered.listen(_sendToBackend);
    try {
      await _fcm.register();
    } catch (e) {
      // Registrasi bisa gagal (mis. APNs belum siap di iOS); notifikasi tidak boleh membuat app gagal.
      debugPrint('[push] register gagal: $e');
    }
    // `onRegistered` hanya terpicu saat registrasi FCM baru; perangkat yang sudah terdaftar tidak memancarkannya
    // lagi, sehingga bila backend kehilangan datanya (dihapus, akun baru) push tidak pernah sampai.
    // FID = Firebase Installation ID yang sama: kirim ulang tiap sesi (PUT idempoten di backend).
    try {
      await _sendToBackend(await FirebaseInstallations.instance.getId());
    } catch (e) {
      debugPrint('[push] ambil FID gagal: $e');
    }
  }

  /// Dipanggil sebelum logout, selagi token masih ada.
  /// `unregister()` mematikan FID di FCM: walau DELETE gagal atau FID tidak diketahui (registrasi lama
  /// tidak selalu memancarkan `onRegistered` lagi), backend menghapusnya saat kirim berikutnya ditolak.
  Future<void> unregisterDevice() async {
    await _registered?.cancel();
    _registered = null;
    final fid = _fid;
    _fid = null;
    final api = _api;
    if (fid != null && api != null) {
      try {
        await api.delete('/api/mobile/devices', body: {'token': fid});
      } catch (_) {}
    }
    try {
      await _fcm.unregister();
    } catch (_) {}
  }

  Future<void> _sendToBackend(String fid) async {
    _fid = fid;
    final api = _api;
    if (api == null) return debugPrint('[push] mode fixture: perangkat tidak didaftarkan');
    try {
      // Backend menyimpan FID di field `token` (lihat PushDevice di backend).
      await api.put('/api/mobile/devices', body: {'token': fid, 'platform': Platform.isIOS ? 'ios' : 'android'});
      debugPrint('[push] perangkat terdaftar di backend');
    } catch (e) {
      debugPrint('[push] daftar ke backend gagal: $e');
      // Gagal (mis. offline) dicoba lagi saat sesi berikutnya (app dibuka / login ulang).
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
