import 'package:arah/core/error/result.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/features/cashflow/domain/entities/cashflow.dart';
import 'package:arah/features/cashflow/domain/usecases/cashflow_usecases.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Layar Mutasi kas: filter aset ([assetId] `null` = semua) & rentang hari.
class CashMovementsCubit extends Cubit<ViewState<CashMovementPage>> {
  CashMovementsCubit({required GetCashMovements get, required ReverseCashMovement reverse, this.assetId})
    : _get = get,
      _reverse = reverse,
      super(const ViewState());

  final GetCashMovements _get;
  final ReverseCashMovement _reverse;
  String? assetId;
  int days = 30;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get((assetId: assetId, days: days))));
  }

  Future<void> select({String? assetId, int? days}) {
    this.assetId = assetId;
    if (days != null) this.days = days;
    return load();
  }

  Future<Result<void>> reverse(String id) async {
    final result = await _reverse(id);
    if (result is Success<void>) await load();
    return result;
  }
}
