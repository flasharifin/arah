import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/portfolio/domain/entities/performance.dart';
import 'package:arah/features/portfolio/domain/repositories/performance_repository.dart';

class GetDailyPerformance implements UseCase<List<DailyPerformance>, NoParams> {
  const GetDailyPerformance(this._repository);
  final PerformanceRepository _repository;

  @override
  Future<Result<List<DailyPerformance>>> call(NoParams params) => _repository.getDaily();
}

class GetSales implements UseCase<List<SaleRecord>, NoParams> {
  const GetSales(this._repository);
  final PerformanceRepository _repository;

  @override
  Future<Result<List<SaleRecord>>> call(NoParams params) => _repository.getSales();
}
