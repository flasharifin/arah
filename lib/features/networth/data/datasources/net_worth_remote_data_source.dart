import 'package:arah/core/domain/money.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';

/// Kontrak `/api/networth` + `/api/settings` (target). Baru implementasi fixture.
abstract interface class NetWorthRemoteDataSource {
  Future<NetWorth> fetchNetWorth();
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
