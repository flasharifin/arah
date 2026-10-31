import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/settings/domain/entities/account_settings.dart';
import 'package:arah/features/settings/domain/repositories/settings_repository.dart';

class GetSettings implements UseCase<AccountSettings, NoParams> {
  const GetSettings(this._repository);
  final SettingsRepository _repository;

  @override
  Future<Result<AccountSettings>> call(NoParams params) => _repository.get();
}

class SaveSettings implements UseCase<AccountSettings, ({String? telegramChatId, double drawdownThreshold})> {
  const SaveSettings(this._repository);
  final SettingsRepository _repository;

  @override
  Future<Result<AccountSettings>> call(({String? telegramChatId, double drawdownThreshold}) p) =>
      _repository.save(telegramChatId: p.telegramChatId, drawdownThreshold: p.drawdownThreshold);
}
