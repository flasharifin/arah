import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';

abstract interface class NetWorthRemoteDataSource {
  Future<NetWorth> fetchNetWorth();
}

/// Aset & utang dari `/api/summary` (nilai sudah dikonversi ke rupiah oleh server) + target dari `/api/settings`.
class NetWorthApiDataSource implements NetWorthRemoteDataSource {
  const NetWorthApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<NetWorth> fetchNetWorth() async {
    final results = await Future.wait([_api.get('/api/summary'), _api.get('/api/settings')]);
    final s = results[0] as Map<String, dynamic>;
    final settings = results[1] as Map<String, dynamic>;
    final positionCount = (s['portfolioSummary'] as Map<String, dynamic>)['count'] as num;
    double num_(Object? v) => (v as num).toDouble();

    return NetWorth(
      asOf: DateTime.parse((s['asOf'] as Map<String, dynamic>)['computedAt'] as String),
      assets: [
        if (positionCount > 0)
          WealthItem(
            id: 'portfolio',
            name: 'Portofolio investasi',
            category: WealthCategory.portfolio,
            value: Money.idr(num_(s['portfolioValueIDR'])),
            isAutomatic: true,
          ),
        for (final a in (s['manualAssets'] as List<dynamic>).cast<Map<String, dynamic>>())
          WealthItem(
            id: a['id'] as String,
            name: a['name'] as String,
            category: _category(a['category'] as String),
            value: Money.idr(num_(a['valueIDR'])),
          ),
      ],
      liabilities: [
        for (final l in (s['liabilityItems'] as List<dynamic>).cast<Map<String, dynamic>>())
          WealthItem(
            id: l['id'] as String,
            name: l['name'] as String,
            category: WealthCategory.debt,
            value: Money.idr(num_(l['amountIDR'])),
          ),
      ],
      goal: WealthGoal(
        name: settings['goalName'] as String? ?? 'Target kekayaan',
        target: Money.idr(num_(settings['wealthTarget'])),
        deadline: switch (settings['goalDeadline']) {
          final String d => DateTime.parse(d),
          _ => null,
        },
        monthlyContribution: switch (settings['goalMonthlyContrib']) {
          final num v => Money.idr(v.toDouble()),
          _ => null,
        },
        expectedReturnPercent: (settings['goalReturnPct'] as num?)?.toDouble(),
      ),
    );
  }

  // Enum AssetCategory backend; stock/crypto manual (di luar portofolio) masuk Lainnya.
  static WealthCategory _category(String backend) => switch (backend) {
    'cash' => WealthCategory.cash,
    'mutual_fund' => WealthCategory.mutualFund,
    'property' => WealthCategory.property,
    'gold' => WealthCategory.gold,
    'defi' => WealthCategory.defi,
    _ => WealthCategory.other,
  };
}

/// Fixture S07: aset 148,45 jt − utang 20 jt = 128,45 jt; target 1 M.
class NetWorthFixtureDataSource implements NetWorthRemoteDataSource {
  @override
  Future<NetWorth> fetchNetWorth() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return NetWorth(
      asOf: DateTime.now(),
      assets: const [
        WealthItem(
          id: 'portfolio',
          name: 'Portofolio investasi',
          category: WealthCategory.portfolio,
          value: Money.idr(98450000),
          isAutomatic: true,
        ),
        WealthItem(id: 'cash', name: 'Tabungan', category: WealthCategory.cash, value: Money.idr(30000000)),
        WealthItem(id: 'gold', name: 'Emas', category: WealthCategory.gold, value: Money.idr(20000000)),
      ],
      liabilities: const [
        WealthItem(
          id: 'vehicle',
          name: 'Cicilan kendaraan',
          category: WealthCategory.debt,
          value: Money.idr(20000000),
        ),
      ],
      goal: WealthGoal(
        name: 'Road to 1M',
        target: const Money.idr(1000000000),
        deadline: DateTime(2035, 12, 31),
        monthlyContribution: const Money.idr(5000000),
        expectedReturnPercent: 10,
      ),
    );
  }
}
