import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hanya rute internal dari payload yang diterima', () {
    expect(PushNotificationService.safeRoute('/portfolio/bbca'), '/portfolio/bbca');
    expect(PushNotificationService.safeRoute('https://evil.example'), isNull);
    expect(PushNotificationService.safeRoute('//evil.example'), isNull);
    expect(PushNotificationService.safeRoute(null), isNull);
    expect(PushNotificationService.safeRoute(1), isNull);
  });

  test('judul/isi dari blok notification, fallback ke data untuk data-only', () {
    const withNotification = RemoteMessage(
      notification: RemoteNotification(title: 'Harga', body: 'BBCA naik'),
      data: {'title': 'abaikan'},
    );
    expect(PushNotificationService.contentOf(withNotification), (title: 'Harga', body: 'BBCA naik'));

    const dataOnly = RemoteMessage(data: {'title': 'Briefing', 'body': 'Siap dibaca'});
    expect(PushNotificationService.contentOf(dataOnly), (title: 'Briefing', body: 'Siap dibaca'));
  });
}
