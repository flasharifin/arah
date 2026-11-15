import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/cashflow/data/datasources/cashflow_remote_data_source.dart';
import 'package:arah/features/cashflow/domain/entities/cashflow.dart';
import 'package:arah/features/cashflow/domain/repositories/cashflow_repository.dart';

class CashflowRepositoryImpl implements CashflowRepository {
  const CashflowRepositoryImpl(this._remote);
  final CashflowRemoteDataSource _remote;

  @override
  Future<Result<CashflowOverview>> overview(DateTime month) => guard(() => _remote.overview(month));

  @override
  Future<Result<CashMovementPage>> movements({String? assetId, int days = 30}) =>
      guard(() => _remote.movements(assetId: assetId, days: days));

  @override
  Future<Result<void>> reverse(String movementId) => guard(() => _remote.reverse(movementId));

  @override
  Future<Result<void>> saveSettings(CashflowSettings settings) => guard(() => _remote.saveSettings(settings));
}
