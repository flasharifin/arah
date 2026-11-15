import 'package:arah/core/error/result.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/features/cashflow/domain/entities/cashflow.dart';
import 'package:arah/features/cashflow/domain/usecases/cashflow_usecases.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Tab Arus kas & kartu "Bulan ini" di Beranda; hidup selama sesi (shell).
class CashflowCubit extends Cubit<ViewState<CashflowOverview>> {
  CashflowCubit({required GetCashflow get, required SaveCashflowSettings saveSettings, DateTime? month})
    : _get = get,
      _saveSettings = saveSettings,
      month = month ?? DateTime(DateTime.now().year, DateTime.now().month),
      super(const ViewState());

  final GetCashflow _get;
  final SaveCashflowSettings _saveSettings;
  DateTime month;

  bool get isCurrentMonth {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month;
  }

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(month)));
  }

  Future<void> shiftMonth(int delta) {
    month = DateTime(month.year, month.month + delta);
    return load();
  }

  Future<Result<void>> saveSettings(CashflowSettings s) async {
    final result = await _saveSettings(s);
    if (result is Success<void>) await load();
    return result;
  }
}
