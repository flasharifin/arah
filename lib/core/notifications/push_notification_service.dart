import 'package:firebase_messaging/firebase_messaging.dart';

/// FCM: izin, token, pesan saat app terbuka, dan rute dari notifikasi yang di-tap.
/// Rute dibaca dari `data.route` pada payload, mis. `{"route": "/portfolio/bbca"}`.
class PushNotificationService {
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

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

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  /// Rute dari notifikasi yang dibuka, termasuk yang membuka app dari kondisi tertutup.
  Stream<String> openedRoutes() async* {
    final initial = await _fcm.getInitialMessage();
    final initialRoute = initial == null ? null : routeOf(initial);
    if (initialRoute != null) yield initialRoute;
    yield* FirebaseMessaging.onMessageOpenedApp.map(routeOf).where((r) => r != null).cast<String>();
  }

  /// Payload datang dari luar app: hanya rute internal yang diterima.
  static String? routeOf(RemoteMessage message) {
    final route = message.data['route'];
    return route is String && route.startsWith('/') && !route.startsWith('//') ? route : null;
  }
}
