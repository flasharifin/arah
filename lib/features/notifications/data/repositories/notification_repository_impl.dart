import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/notifications/data/datasources/notification_remote_data_source.dart';
import 'package:arah/features/notifications/domain/entities/app_notification.dart';
import 'package:arah/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this._remote);
  final NotificationRemoteDataSource _remote;

  @override
  Future<Result<List<AppNotification>>> list() => guard(_remote.list);

  @override
  Future<Result<int>> unreadCount() => guard(_remote.unreadCount);

  @override
  Future<Result<void>> markRead(String? id) => guard(() => _remote.markRead(id));

  @override
  Future<Result<NotificationPrefs>> getPrefs() => guard(_remote.getPrefs);

  @override
  Future<Result<void>> savePrefs(NotificationPrefs prefs) => guard(() => _remote.savePrefs(prefs));
}
