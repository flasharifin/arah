import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/notifications/domain/entities/app_notification.dart';

abstract interface class NotificationRemoteDataSource {
  Future<List<AppNotification>> list();
  Future<int> unreadCount();
  Future<void> markRead(String? id);
  Future<NotificationPrefs> getPrefs();
  Future<void> savePrefs(NotificationPrefs prefs);
}

/// `/api/mobile/notifications`: riwayat 100 terbaru, tandai dibaca, dan preferensi push.
class NotificationApiDataSource implements NotificationRemoteDataSource {
  const NotificationApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<List<AppNotification>> list() async => [
    for (final n in (await _api.get('/api/mobile/notifications') as List<dynamic>).cast<Map<String, dynamic>>())
      AppNotification(
        id: n['id'] as String,
        type: NotificationType.fromCode(n['type'] as String?),
        title: n['title'] as String,
        body: n['body'] as String,
        route: n['route'] as String?,
        isRead: n['readAt'] != null,
        createdAt: DateTime.parse(n['createdAt'] as String).toLocal(),
      ),
  ];

  @override
  Future<int> unreadCount() async =>
      ((await _api.get('/api/mobile/notifications/unread-count') as Map<String, dynamic>)['count'] as num).toInt();

  @override
  Future<void> markRead(String? id) => _api.patch('/api/mobile/notifications', body: id == null ? {'all': true} : {'id': id});

  @override
  Future<NotificationPrefs> getPrefs() async {
    final data = await _api.get('/api/mobile/notifications/preferences') as Map<String, dynamic>;
    final disabled = (data['disabledTypes'] as List<dynamic>).cast<String>().toSet();
    return NotificationPrefs(
      mode: NotificationMode.fromCode(data['mode'] as String?),
      disabled: NotificationType.values.where((t) => disabled.contains(t.code)).toSet(),
      holdNight: data['holdNight'] == true,
    );
  }

  @override
  Future<void> savePrefs(NotificationPrefs prefs) => _api.put(
    '/api/mobile/notifications/preferences',
    body: {
      'mode': prefs.mode.code,
      'disabledTypes': [for (final t in prefs.disabled) t.code],
      'holdNight': prefs.holdNight,
    },
  );
}

/// Data ilustrasi, disimpan di memori.
class NotificationFixtureDataSource implements NotificationRemoteDataSource {
  NotificationPrefs _prefs = const NotificationPrefs();
  late final List<AppNotification> _items = () {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    return [
      AppNotification(
        id: 'n1',
        type: NotificationType.briefing,
        title: 'Selamat Pagi!',
        body: 'Pasar Kemarin:\nIHSG 7.250 (+0,42%)\nS&P500 5.800 (−0,18%)\nHari Ini Perhatikan:\nTLKM: RSI 28 (oversold), potensi rebound',
        route: '/home',
        createdAt: now,
      ),
      AppNotification(
        id: 'n2',
        type: NotificationType.priceAlert,
        title: 'Price Alert Terpenuhi!',
        body: 'BBRI menyentuh target Rp 4.500',
        route: '/portfolio',
        createdAt: now,
      ),
      AppNotification(
        id: 'n3',
        type: NotificationType.dailySummary,
        title: 'Road To 1M',
        body: 'Porto naik Rp 1.250.000 (+0,98%)',
        route: '/portfolio',
        createdAt: yesterday,
        isRead: true,
      ),
      AppNotification(
        id: 'n4',
        type: NotificationType.periodic,
        title: 'Laporan Bulanan',
        body: 'Return bulan ini +2,40%\nDividen masuk Rp 320.000',
        createdAt: yesterday,
        isRead: true,
      ),
    ];
  }();

  @override
  Future<List<AppNotification>> list() async => List.of(_items);

  @override
  Future<int> unreadCount() async => _items.where((n) => !n.isRead).length;

  @override
  Future<void> markRead(String? id) async {
    for (var i = 0; i < _items.length; i++) {
      if (id == null || _items[i].id == id) _items[i] = _items[i].read();
    }
  }

  @override
  Future<NotificationPrefs> getPrefs() async => _prefs;

  @override
  Future<void> savePrefs(NotificationPrefs prefs) async => _prefs = prefs;
}
