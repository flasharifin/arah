import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/portfolio/domain/entities/technical.dart';
import 'package:arah/features/portfolio/domain/repositories/technical_repository.dart';

/// Parameter: id posisi (portfolio id).
class GetTechnical implements UseCase<TechnicalAnalysis, String> {
  const GetTechnical(this._repository);
  final TechnicalRepository _repository;

  @override
  Future<Result<TechnicalAnalysis>> call(String positionId) => _repository.get(positionId);
}
