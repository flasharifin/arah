import 'package:arah/core/error/result.dart';
import 'package:arah/features/dashboard/domain/entities/dashboard_summary.dart';

abstract interface class DashboardRepository {
  Future<Result<DashboardSummary>> getSummary();
}
