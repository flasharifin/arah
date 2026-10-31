import 'package:arah/core/error/result.dart';
import 'package:arah/features/portfolio/domain/entities/technical.dart';

abstract interface class TechnicalRepository {
  Future<Result<TechnicalAnalysis>> get(String positionId);
}
