import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/calculator/domain/entities/insights.dart';
import 'package:arah/features/calculator/domain/repositories/insights_repository.dart';

class GetInvisibleCost implements UseCase<List<InvisibleCost>, NoParams> {
  const GetInvisibleCost(this._repository);
  final InsightsRepository _repository;

  @override
  Future<Result<List<InvisibleCost>>> call(NoParams params) => _repository.invisibleCost();
}

class GetWealthTimeline implements UseCase<WealthTimeline, NoParams> {
  const GetWealthTimeline(this._repository);
  final InsightsRepository _repository;

  @override
  Future<Result<WealthTimeline>> call(NoParams params) => _repository.wealthTimeline();
}
