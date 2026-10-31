import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/analysis/domain/entities/technical_rank.dart';
import 'package:arah/features/analysis/domain/repositories/technical_rank_repository.dart';

class GetTechnicalRanking implements UseCase<TechnicalRanking, NoParams> {
  const GetTechnicalRanking(this._repository);
  final TechnicalRankRepository _repository;

  @override
  Future<Result<TechnicalRanking>> call(NoParams params) => _repository.get();
}
