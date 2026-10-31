import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/settings/data/datasources/settings_remote_data_source.dart';
import 'package:arah/features/settings/domain/entities/account_settings.dart';
import 'package:arah/features/settings/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._remote);
  final SettingsRemoteDataSource _remote;

  @override
  Future<Result<AccountSettings>> get() => guard(_remote.fetch);

  @override
  Future<Result<AccountSettings>> save({required String? telegramChatId, required double drawdownThreshold}) =>
      guard(() => _remote.save(telegramChatId: telegramChatId, drawdownThreshold: drawdownThreshold));
}
