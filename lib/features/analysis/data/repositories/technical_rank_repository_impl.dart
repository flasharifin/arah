import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/analysis/data/datasources/technical_rank_remote_data_source.dart';
import 'package:arah/features/analysis/domain/entities/technical_rank.dart';
import 'package:arah/features/analysis/domain/repositories/technical_rank_repository.dart';

class TechnicalRankRepositoryImpl implements TechnicalRankRepository {
  const TechnicalRankRepositoryImpl(this._remote);
  final TechnicalRankRemoteDataSource _remote;

  @override
  Future<Result<TechnicalRanking>> get() => guard(_remote.fetch);
}
