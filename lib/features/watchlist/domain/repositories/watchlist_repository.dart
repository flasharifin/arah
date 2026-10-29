import 'package:arah/core/error/result.dart';
import 'package:arah/features/watchlist/domain/entities/watch_item.dart';

abstract interface class WatchlistRepository {
  Future<Result<List<WatchItem>>> list();

  /// [id] null = tambah baru.
  Future<Result<void>> save(WatchDraft draft, {String? id});
  Future<Result<void>> remove(String id);
}
