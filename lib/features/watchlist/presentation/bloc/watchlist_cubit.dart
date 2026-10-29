import 'package:arah/core/error/result.dart';
import 'package:arah/core/state/view_state.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/watchlist/domain/entities/watch_item.dart';
import 'package:arah/features/watchlist/domain/usecases/watchlist_usecases.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WatchlistCubit extends Cubit<ViewState<List<WatchItem>>> {
  WatchlistCubit({required GetWatchlist get, required SaveWatchItem save, required RemoveWatchItem remove})
    : _get = get,
      _save = save,
      _remove = remove,
      super(const ViewState());

  final GetWatchlist _get;
  final SaveWatchItem _save;
  final RemoveWatchItem _remove;

  Future<void> load() async {
    emit(state.loading());
    emit(state.fromResult(await _get(const NoParams())));
  }

  /// Sukses → muat ulang supaya harga & jarak target ikut dihitung server.
  Future<Result<void>> save(WatchDraft draft, {String? id}) async {
    final result = await _save((draft: draft, id: id));
    if (result is Success<void>) await load();
    return result;
  }

  Future<Result<void>> remove(String id) async {
    final result = await _remove(id);
    if (result is Success<void>) await load();
    return result;
  }
}
