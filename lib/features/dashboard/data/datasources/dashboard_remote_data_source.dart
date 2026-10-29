import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/dashboard/domain/entities/dashboard_summary.dart';

/// Ringkasan beranda.
abstract interface class DashboardRemoteDataSource {
  Future<DashboardSummary> fetchSummary();
}

/// Angka dari `/api/summary` (dihitung server, sama dengan dashboard web) + briefing terakhir.
class DashboardApiDataSource implements DashboardRemoteDataSource {
  const DashboardApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<DashboardSummary> fetchSummary() async {
    final results = await Future.wait([_api.get('/api/summary'), _api.get('/api/brief/today')]);
    final s = results[0] as Map<String, dynamic>;
    final brief = results[1] as Map<String, dynamic>?;
    Money idr(String key) => Money.idr((s[key] as num).toDouble());

    return DashboardSummary(
      netWorth: idr('combinedNetWorth'),
      totalAssets: idr('totalAssetsAll'),
      totalLiabilities: idr('totalLiabilities'),
      portfolioValue: idr('portfolioValueIDR'),
      healthScore: ((s['healthScore'] as Map<String, dynamic>?)?['total'] as num?)?.toInt(),
      goalTarget: idr('target'),
      asOf: DateTime.parse((s['asOf'] as Map<String, dynamic>)['computedAt'] as String),
      briefing: brief == null
          ? null
          : BriefingPreview(
              date: DateTime.parse(brief['date'] as String),
              summary: briefingText(brief['content'] as String),
            ),
    );
  }

  /// Briefing disimpan dalam MarkdownV2 Telegram: buang penanda format & escape, lewati baris judul.
  static String briefingText(String markdownV2) {
    final plain = markdownV2.replaceAllMapped(RegExp(r'\\(.)|\|\||[*_~`]'), (m) => m[1] ?? '');
    final lines = plain.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return lines.skip(lines.length > 1 ? 1 : 0).join(' · ');
  }
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
