import 'package:arah/core/error/result.dart';
import 'package:arah/features/calculator/domain/entities/insights.dart';

abstract interface class InsightsRepository {
  Future<Result<List<InvisibleCost>>> invisibleCost();
  Future<Result<WealthTimeline>> wealthTimeline();
}
