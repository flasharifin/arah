import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/notifications/domain/entities/app_notification.dart';
import 'package:arah/features/notifications/domain/repositories/notification_repository.dart';

class GetNotifications implements UseCase<List<AppNotification>, NoParams> {
  const GetNotifications(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Result<List<AppNotification>>> call(NoParams params) => _repository.list();
}

class GetUnreadNotificationCount implements UseCase<int, NoParams> {
  const GetUnreadNotificationCount(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Result<int>> call(NoParams params) => _repository.unreadCount();
}

/// Parameter: id notifikasi; null = semua.
class MarkNotificationRead implements UseCase<void, String?> {
  const MarkNotificationRead(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Result<void>> call(String? id) => _repository.markRead(id);
}

class GetNotificationPrefs implements UseCase<NotificationPrefs, NoParams> {
  const GetNotificationPrefs(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Result<NotificationPrefs>> call(NoParams params) => _repository.getPrefs();
}

class SaveNotificationPrefs implements UseCase<void, NotificationPrefs> {
  const SaveNotificationPrefs(this._repository);
  final NotificationRepository _repository;

  @override
  Future<Result<void>> call(NotificationPrefs prefs) => _repository.savePrefs(prefs);
}
