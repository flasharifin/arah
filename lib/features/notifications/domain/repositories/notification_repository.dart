import 'package:arah/core/error/result.dart';
import 'package:arah/features/notifications/domain/entities/app_notification.dart';

abstract interface class NotificationRepository {
  Future<Result<List<AppNotification>>> list();
  Future<Result<int>> unreadCount();

  /// [id] null = semua.
  Future<Result<void>> markRead(String? id);
  Future<Result<NotificationPrefs>> getPrefs();
  Future<Result<void>> savePrefs(NotificationPrefs prefs);
}
