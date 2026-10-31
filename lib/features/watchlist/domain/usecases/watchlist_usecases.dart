import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/watchlist/domain/entities/watch_item.dart';
import 'package:arah/features/watchlist/domain/repositories/watchlist_repository.dart';

class GetWatchlist implements UseCase<List<WatchItem>, NoParams> {
  const GetWatchlist(this._repository);
  final WatchlistRepository _repository;

  @override
  Future<Result<List<WatchItem>>> call(NoParams params) => _repository.list();
}

class SaveWatchItem implements UseCase<void, ({WatchDraft draft, String? id})> {
  const SaveWatchItem(this._repository);
  final WatchlistRepository _repository;

  @override
  Future<Result<void>> call(({WatchDraft draft, String? id}) params) => _repository.save(params.draft, id: params.id);
}

/// Parameter: id item.
class RemoveWatchItem implements UseCase<void, String> {
  const RemoveWatchItem(this._repository);
  final WatchlistRepository _repository;

  @override
  Future<Result<void>> call(String id) => _repository.remove(id);
}
