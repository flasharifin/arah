import 'package:arah/core/error/result.dart';
import 'package:arah/features/analysis/domain/entities/technical_rank.dart';

abstract interface class TechnicalRankRepository {
  Future<Result<TechnicalRanking>> get();
}
