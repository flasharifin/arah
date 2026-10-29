import 'package:arah/core/notifications/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? route(Object? value) => PushNotificationService.routeOf(RemoteMessage(data: {'route': ?value}));

  test('hanya rute internal dari payload yang diterima', () {
    expect(route('/portfolio/bbca'), '/portfolio/bbca');
    expect(route('https://evil.example'), isNull);
    expect(route('//evil.example'), isNull);
    expect(route(null), isNull);
    expect(route(1), isNull);
  });
}
