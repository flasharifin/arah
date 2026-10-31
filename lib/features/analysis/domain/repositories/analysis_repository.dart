import 'package:arah/core/error/result.dart';
import 'package:arah/features/analysis/domain/entities/risk_analysis.dart';

abstract interface class AnalysisRepository {
  Future<Result<RiskAnalysis>> get();
}
