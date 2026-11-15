import 'package:arah/core/error/result.dart';
import 'package:arah/features/cashflow/domain/entities/cashflow.dart';

abstract interface class CashflowRepository {
  Future<Result<CashflowOverview>> overview(DateTime month);
  Future<Result<CashMovementPage>> movements({String? assetId, int days});
  Future<Result<void>> reverse(String movementId);
  Future<Result<void>> saveSettings(CashflowSettings settings);
}
