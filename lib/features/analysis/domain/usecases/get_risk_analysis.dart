import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/analysis/domain/entities/risk_analysis.dart';
import 'package:arah/features/analysis/domain/repositories/analysis_repository.dart';

class GetRiskAnalysis implements UseCase<RiskAnalysis, NoParams> {
  const GetRiskAnalysis(this._repository);
  final AnalysisRepository _repository;

  @override
  Future<Result<RiskAnalysis>> call(NoParams params) => _repository.get();
}
