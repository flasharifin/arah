import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/watchlist/data/datasources/watchlist_remote_data_source.dart';
import 'package:arah/features/watchlist/domain/entities/watch_item.dart';
import 'package:arah/features/watchlist/domain/repositories/watchlist_repository.dart';

class WatchlistRepositoryImpl implements WatchlistRepository {
  const WatchlistRepositoryImpl(this._remote);
  final WatchlistRemoteDataSource _remote;

  @override
  Future<Result<List<WatchItem>>> list() => guard(_remote.list);

  @override
  Future<Result<void>> save(WatchDraft draft, {String? id}) => guard(() => _remote.save(draft, id: id));

  @override
  Future<Result<void>> remove(String id) => guard(() => _remote.remove(id));
}
