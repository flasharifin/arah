import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/cashflow/domain/entities/cashflow.dart';
import 'package:arah/features/cashflow/domain/repositories/cashflow_repository.dart';

/// Parameter: bulan (hari diabaikan).
class GetCashflow implements UseCase<CashflowOverview, DateTime> {
  const GetCashflow(this._repository);
  final CashflowRepository _repository;

  @override
  Future<Result<CashflowOverview>> call(DateTime month) => _repository.overview(month);
}

class GetCashMovements implements UseCase<CashMovementPage, ({String? assetId, int days})> {
  const GetCashMovements(this._repository);
  final CashflowRepository _repository;

  @override
  Future<Result<CashMovementPage>> call(({String? assetId, int days}) p) =>
      _repository.movements(assetId: p.assetId, days: p.days);
}

/// Parameter: id mutasi.
class ReverseCashMovement implements UseCase<void, String> {
  const ReverseCashMovement(this._repository);
  final CashflowRepository _repository;

  @override
  Future<Result<void>> call(String id) => _repository.reverse(id);
}

class SaveCashflowSettings implements UseCase<void, CashflowSettings> {
  const SaveCashflowSettings(this._repository);
  final CashflowRepository _repository;

  @override
  Future<Result<void>> call(CashflowSettings settings) => _repository.saveSettings(settings);
}
