import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/analysis/data/datasources/analysis_remote_data_source.dart';
import 'package:arah/features/analysis/domain/entities/risk_analysis.dart';
import 'package:arah/features/analysis/domain/repositories/analysis_repository.dart';

class AnalysisRepositoryImpl implements AnalysisRepository {
  const AnalysisRepositoryImpl(this._remote);
  final AnalysisRemoteDataSource _remote;

  @override
  Future<Result<RiskAnalysis>> get() => guard(_remote.fetch);
}
