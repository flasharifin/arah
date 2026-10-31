import 'package:arah/core/error/result.dart';
import 'package:arah/features/settings/domain/entities/account_settings.dart';

abstract interface class SettingsRepository {
  Future<Result<AccountSettings>> get();

  /// Mengembalikan pengaturan seperti tersimpan di server.
  Future<Result<AccountSettings>> save({required String? telegramChatId, required double drawdownThreshold});
}
