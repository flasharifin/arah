import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/letter/domain/entities/investor_letter.dart';

abstract interface class LetterRemoteDataSource {
  Future<InvestorLetter> fetch();
}

class LetterApiDataSource implements LetterRemoteDataSource {
  const LetterApiDataSource(this._api);
  final ApiClient _api;

  static double _n(Object? v) => (v as num).toDouble();

  static List<Mover> _movers(Object? raw) => [
    for (final m in (raw as List<dynamic>).cast<Map<String, dynamic>>())
      (symbol: m['stockCode'] as String, exchange: m['exchange'] as String, percent: _n(m['pct'])),
  ];

  /// Penjualan ditampilkan per transaksi dalam mata uang asal, jadi total rupiah server tidak dipakai.
  @override
  Future<InvestorLetter> fetch() async {
    final l = await _api.get('/api/investor-letter') as Map<String, dynamic>;
    return InvestorLetter(
      weekStart: DateTime.parse(l['weekStart'] as String),
      weekEnd: DateTime.parse(l['weekEnd'] as String),
      portfolioValue: Money.idr(_n(l['currentPortfolioValue'])),
      weeklyChange: Money.idr(_n(l['weeklyChangeIDR'])),
      weeklyChangePercent: _n(l['weeklyChangePct']),
      ihsgPercent: _n(l['ihsgWeeklyPct']),
      sp500Percent: _n(l['sp500WeeklyPct']),
      weekHigh: Money.idr(_n(l['weekHighValue'])),
      weekLow: Money.idr(_n(l['weekLowValue'])),
      topGainers: _movers(l['topGainers']),
      topLosers: _movers(l['topLosers']),
      sales: [
        for (final s in (l['salesThisWeek'] as List<dynamic>).cast<Map<String, dynamic>>())
          (
            symbol: s['stockCode'] as String,
            realizedPnl: Money(_n(s['realizedPnl']), s['currency'] == 'USD' ? Currency.usd : Currency.idr),
            date: DateTime.parse(s['date'] as String),
          ),
      ],
      // shortcut: dividen dianggap rupiah (tabel dividen tanpa kolom mata uang); ubah bila dividen US dicatat.
      dividends: [
        for (final d in (l['dividendsThisWeek'] as List<dynamic>).cast<Map<String, dynamic>>())
          (
            symbol: d['stockCode'] as String,
            received: Money.idr(_n(d['receivedAmount'])),
            date: switch (d['date']) {
              final String s => DateTime.parse(s),
              _ => null,
            },
          ),
      ],
      positionCount: (l['positionCount'] as num).toInt(),
    );
  }
}

class LetterFixtureDataSource implements LetterRemoteDataSource {
  @override
  Future<InvestorLetter> fetch() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    return InvestorLetter(
      weekStart: end.subtract(const Duration(days: 7)),
      weekEnd: end,
      portfolioValue: const Money.idr(98450000),
      weeklyChange: const Money.idr(1250000),
      weeklyChangePercent: 1.29,
      ihsgPercent: 0.84,
      sp500Percent: 1.52,
      weekHigh: const Money.idr(98900000),
      weekLow: const Money.idr(96800000),
      topGainers: const [
        (symbol: 'AAPL', exchange: 'US', percent: 7.6),
        (symbol: 'BBCA', exchange: 'IDX', percent: 5.56),
      ],
      topLosers: const [(symbol: 'TLKM', exchange: 'IDX', percent: -7.81)],
      sales: [(symbol: 'ASII', realizedPnl: const Money.idr(450000), date: end.subtract(const Duration(days: 2)))],
      dividends: const [],
      positionCount: 4,
    );
  }
}
