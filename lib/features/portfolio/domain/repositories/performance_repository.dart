import 'package:arah/core/error/result.dart';
import 'package:arah/features/portfolio/domain/entities/performance.dart';

abstract interface class PerformanceRepository {
  Future<Result<List<DailyPerformance>>> getDaily();
  Future<Result<List<SaleRecord>>> getSales();
}
