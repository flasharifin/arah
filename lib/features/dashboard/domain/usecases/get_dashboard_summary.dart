import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:arah/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetDashboardSummary implements UseCase<DashboardSummary, NoParams> {
  const GetDashboardSummary(this._repository);
  final DashboardRepository _repository;

  @override
  Future<Result<DashboardSummary>> call(NoParams params) => _repository.getSummary();
}
