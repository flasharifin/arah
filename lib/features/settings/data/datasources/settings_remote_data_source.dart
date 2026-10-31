import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/settings/domain/entities/account_settings.dart';

abstract interface class SettingsRemoteDataSource {
  Future<AccountSettings> fetch();
  Future<AccountSettings> save({required String? telegramChatId, required double drawdownThreshold});
}

class SettingsApiDataSource implements SettingsRemoteDataSource {
  const SettingsApiDataSource(this._api);
  final ApiClient _api;

  static AccountSettings _parse(Map<String, dynamic> s) => AccountSettings(
    wealthTarget: Money.idr((s['wealthTarget'] as num).toDouble()),
    drawdownThreshold: (s['drawdownThreshold'] as num).toDouble(),
    telegramChatId: s['telegramChatId'] as String?,
  );

  @override
  Future<AccountSettings> fetch() async => _parse(await _api.get('/api/settings') as Map<String, dynamic>);

  /// Chat ID kosong = matikan notifikasi Telegram; bukan angka → server menolak (400).
  @override
  Future<AccountSettings> save({required String? telegramChatId, required double drawdownThreshold}) async => _parse(
    await _api.put(
          '/api/settings',
          body: {'telegramChatId': telegramChatId ?? '', 'drawdownThreshold': drawdownThreshold},
        )
        as Map<String, dynamic>,
  );
}

class SettingsFixtureDataSource implements SettingsRemoteDataSource {
  var _settings = const AccountSettings(wealthTarget: Money.idr(1000000000), drawdownThreshold: 10);

  @override
  Future<AccountSettings> fetch() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _settings;
  }

  @override
  Future<AccountSettings> save({required String? telegramChatId, required double drawdownThreshold}) async =>
      _settings = AccountSettings(
        wealthTarget: _settings.wealthTarget,
        drawdownThreshold: drawdownThreshold,
        telegramChatId: telegramChatId,
      );
}
