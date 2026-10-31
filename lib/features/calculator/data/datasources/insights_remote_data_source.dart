import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/calculator/domain/entities/insights.dart';

abstract interface class InsightsRemoteDataSource {
  Future<List<InvisibleCost>> invisibleCost();
  Future<WealthTimeline> wealthTimeline();
}

Currency _currency(Object? code) => code == 'USD' ? Currency.usd : Currency.idr;
double _n(Object? v) => (v as num).toDouble();

class InsightsApiDataSource implements InsightsRemoteDataSource {
  const InsightsApiDataSource(this._api);
  final ApiClient _api;

  /// Field `...IDR` per posisi sebenarnya dalam mata uang posisi; total ditampilkan per mata uang di app.
  @override
  Future<List<InvisibleCost>> invisibleCost() async {
    final r = await _api.get('/api/portfolio/invisible-cost') as Map<String, dynamic>;
    return [
      for (final p in (r['positions'] as List<dynamic>).cast<Map<String, dynamic>>())
        () {
          final c = _currency(p['currency']);
          return InvisibleCost(
            symbol: p['stockCode'] as String,
            exchange: p['exchange'] as String,
            costBasis: Money(_n(p['costBasis']), c),
            holdDays: (p['holdDays'] as num).toInt(),
            returnPercent: _n(p['actualReturnPct']),
            ihsgPercent: _n(p['ihsgReturnPct']),
            opportunityCost: Money(_n(p['ocIDR']), c),
            inflation: Money(_n(p['inflationIDR']), c),
            isZombie: p['isZombie'] as bool,
          );
        }(),
    ];
  }

  @override
  Future<WealthTimeline> wealthTimeline() async {
    final r = await _api.get('/api/portfolio/wealth-timeline') as Map<String, dynamic>;
    return WealthTimeline(
      points: [
        for (final p in (r['chartData'] as List<dynamic>).cast<Map<String, dynamic>>())
          (date: DateTime.parse(p['date'] as String), value: Money.idr(_n(p['value']))),
      ],
      events: [
        for (final m in (r['milestones'] as List<dynamic>).cast<Map<String, dynamic>>())
          TimelineEvent(
            date: DateTime.parse(m['date'] as String),
            kind: TimelineKind.values.byName(m['type'] as String),
            label: m['label'] as String,
            amount: Money(_n(m['amount']), _currency(m['currency'])),
          ),
      ],
    );
  }
}

class InsightsFixtureDataSource implements InsightsRemoteDataSource {
  @override
  Future<List<InvisibleCost>> invisibleCost() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const [
      InvisibleCost(
        symbol: 'TLKM',
        exchange: 'IDX',
        costBasis: Money.idr(6400000),
        holdDays: 410,
        returnPercent: -7.81,
        ihsgPercent: 4.2,
        opportunityCost: Money.idr(768640),
        inflation: Money.idr(251616),
        isZombie: false,
      ),
      InvisibleCost(
        symbol: 'BBCA',
        exchange: 'IDX',
        costBasis: Money.idr(90000000),
        holdDays: 200,
        returnPercent: 5.56,
        ihsgPercent: 2.1,
        opportunityCost: Money.idr(0),
        inflation: Money.idr(1726027),
        isZombie: true,
      ),
      InvisibleCost(
        symbol: 'AAPL',
        exchange: 'US',
        costBasis: Money.usd(775.8),
        holdDays: 120,
        returnPercent: 7.6,
        ihsgPercent: 1.4,
        opportunityCost: Money.usd(0),
        inflation: Money.usd(8.93),
        isZombie: false,
      ),
    ];
  }

  @override
  Future<WealthTimeline> wealthTimeline() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final today = DateTime.now();
    return WealthTimeline(
      points: [
        for (var i = 60; i >= 0; i--)
          (date: DateTime(today.year, today.month, today.day - i), value: Money.idr(90000000 + (60 - i) * 140000.0)),
      ],
      events: [
        TimelineEvent(
          date: DateTime(today.year, today.month, today.day - 12),
          kind: TimelineKind.sell,
          label: 'Jual ASII',
          amount: const Money.idr(450000),
        ),
        TimelineEvent(
          date: DateTime(today.year, today.month, today.day - 40),
          kind: TimelineKind.dividend,
          label: 'Dividen BBCA',
          amount: const Money.idr(270000),
        ),
        TimelineEvent(
          date: DateTime(today.year, today.month, today.day - 200),
          kind: TimelineKind.buy,
          label: 'Beli BBCA',
          amount: const Money.idr(90000000),
        ),
      ],
    );
  }
}
