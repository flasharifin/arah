import 'package:arah/core/error/result.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:arah/features/networth/domain/usecases/get_net_worth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NetWorthCubit extends Cubit<ViewState<NetWorth>> {
  NetWorthCubit({
    required GetNetWorth get,
    required SaveWealthEntry save,
    required RemoveWealthEntry remove,
    required CreateNetWorthSnapshot snapshot,
    required RemoveNetWorthSnapshot removeSnapshot,
    required SaveWealthGoal saveGoal,
  }) : _getNetWorth = get,
       _save = save,
       _remove = remove,
       _snapshot = snapshot,
       _removeSnapshot = removeSnapshot,
       _saveGoal = saveGoal,
       super(const ViewState());

  final GetNetWorth _getNetWorth;
  final SaveWealthEntry _save;
  final RemoveWealthEntry _remove;
  final CreateNetWorthSnapshot _snapshot;
  final RemoveNetWorthSnapshot _removeSnapshot;
  final SaveWealthGoal _saveGoal;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _getNetWorth(const NoParams())));
  }

  // Muat ulang setelah berhasil: total & konversi USD/emas dihitung server.
  Future<Result<void>> save(ManualEntry entry, {String? id}) => _thenReload(_save((entry: entry, id: id)));
  Future<Result<void>> remove(WealthKind kind, String id) => _thenReload(_remove((kind: kind, id: id)));
  Future<Result<void>> createSnapshot() => _thenReload(_snapshot(const NoParams()));
  Future<Result<void>> removeSnapshot(String id) => _thenReload(_removeSnapshot(id));
  Future<Result<void>> saveGoal(WealthGoal goal) => _thenReload(_saveGoal(goal));

  Future<Result<void>> _thenReload(Future<Result<void>> action) async {
    final result = await action;
    if (result is Success<void>) await load();
    return result;
  }
}
