import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/portfolio/data/datasources/performance_remote_data_source.dart';
import 'package:arah/features/portfolio/domain/entities/performance.dart';
import 'package:arah/features/portfolio/domain/repositories/performance_repository.dart';

class PerformanceRepositoryImpl implements PerformanceRepository {
  const PerformanceRepositoryImpl(this._remote);
  final PerformanceRemoteDataSource _remote;

  @override
  Future<Result<List<DailyPerformance>>> getDaily() => guard(_remote.fetchDaily);

  @override
  Future<Result<List<SaleRecord>>> getSales() => guard(_remote.fetchSales);
}
