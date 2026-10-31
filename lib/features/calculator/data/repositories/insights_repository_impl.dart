import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/calculator/data/datasources/insights_remote_data_source.dart';
import 'package:arah/features/calculator/domain/entities/insights.dart';
import 'package:arah/features/calculator/domain/repositories/insights_repository.dart';

class InsightsRepositoryImpl implements InsightsRepository {
  const InsightsRepositoryImpl(this._remote);
  final InsightsRemoteDataSource _remote;

  @override
  Future<Result<List<InvisibleCost>>> invisibleCost() => guard(_remote.invisibleCost);

  @override
  Future<Result<WealthTimeline>> wealthTimeline() => guard(_remote.wealthTimeline);
}
