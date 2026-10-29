import 'package:arah/core/domain/money.dart';
import 'package:arah/features/dashboard/domain/entities/dashboard_summary.dart';

/// Ringkasan beranda. Backend belum punya satu endpoint agregat untuk mobile;
/// implementasi API nantinya menggabungkan `/api/networth`, `/api/settings`, `/api/brief/today`.
abstract interface class DashboardRemoteDataSource {
  Future<DashboardSummary> fetchSummary();
}

/// Fixture S02.
class DashboardFixtureDataSource implements DashboardRemoteDataSource {
  @override
  Future<DashboardSummary> fetchSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return DashboardSummary(
      netWorth: const Money.idr(128450000),
      totalAssets: const Money.idr(148450000),
      totalLiabilities: const Money.idr(20000000),
      portfolioValue: const Money.idr(98450000),
      healthScore: 78,
      goalTarget: const Money.idr(1000000000),
      asOf: DateTime.now(),
      briefing: BriefingPreview(
        date: DateTime.now(),
        summary: 'Ringkasan pasar contoh: IHSG bergerak mendatar, sektor perbankan menguat tipis.',
      ),
    );
  }
}
