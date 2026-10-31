import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/analysis/domain/entities/risk_analysis.dart';

abstract interface class AnalysisRemoteDataSource {
  Future<RiskAnalysis> fetch();
}

class AnalysisApiDataSource implements AnalysisRemoteDataSource {
  const AnalysisApiDataSource(this._api);
  final ApiClient _api;

  static double _n(Object? v) => (v as num).toDouble();
  static double? _nOrNull(Object? v) => (v as num?)?.toDouble();

  @override
  Future<RiskAnalysis> fetch() async {
    final r = await _api.get('/api/analysis/risk') as Map<String, dynamic>;
    return RiskAnalysis(
      positions: [
        for (final p in (r['positions'] as List<dynamic>).cast<Map<String, dynamic>>())
          RiskPosition(
            symbol: p['stockCode'] as String,
            exchange: p['exchange'] as String,
            value: Money.idr(_n(p['valueIDR'])),
            weight: _n(p['weight']),
            hasPrice: p['hasPrice'] as bool,
            volatility: _nOrNull(p['volatility']),
            maxDrawdown: _nOrNull(p['maxDrawdown']),
          ),
      ],
      correlations: [
        for (final c in (r['correlations'] as List<dynamic>).cast<Map<String, dynamic>>())
          (a: c['a'] as String, b: c['b'] as String, r: _nOrNull(c['r'])),
      ],
      scenarios: [
        for (final s in (r['scenarios'] as List<dynamic>).cast<Map<String, dynamic>>())
          StressScenario(
            id: s['id'] as String,
            label: s['label'] as String,
            description: s['desc'] as String,
            drops: (idx: _n(s['IDX']), us: _n(s['US']), crypto: _n(s['CRYPTO'])),
          ),
      ],
      historyDays: (r['historyDays'] as num).toInt(),
      portfolio: switch (r['portfolio']) {
        final Map<String, dynamic> p => PortfolioRisk(
          sharpe: _nOrNull(p['sharpe']),
          riskFreePercent: _n(p['riskFreePct']),
          betaIhsg: _nOrNull(p['betaIhsg']),
          betaSp500: _nOrNull(p['betaSp500']),
          betaBtc: _nOrNull(p['betaBtc']),
          days: (p['days'] as num).toInt(),
        ),
        _ => null,
      },
    );
  }
}

/// Fixture S12 (posisi galeri S03), preset skenario sama dengan server.
class AnalysisFixtureDataSource implements AnalysisRemoteDataSource {
  @override
  Future<RiskAnalysis> fetch() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const RiskAnalysis(
      positions: [
        RiskPosition(
          symbol: 'BBCA',
          exchange: 'IDX',
          value: Money.idr(95000000),
          weight: 64.2,
          hasPrice: true,
          volatility: 18.4,
          maxDrawdown: 6.1,
        ),
        RiskPosition(
          symbol: 'TLKM',
          exchange: 'IDX',
          value: Money.idr(5900000),
          weight: 4,
          hasPrice: true,
          volatility: 27.9,
          maxDrawdown: 12.3,
        ),
        RiskPosition(
          symbol: 'AAPL',
          exchange: 'US',
          value: Money.idr(13355000),
          weight: 9,
          hasPrice: true,
          volatility: 21.5,
          maxDrawdown: 4.8,
        ),
        RiskPosition(symbol: 'BTC', exchange: 'CRYPTO', value: Money.idr(33720000), weight: 22.8, hasPrice: false),
      ],
      correlations: [
        (a: 'BBCA:IDX', b: 'TLKM:IDX', r: 0.62),
        (a: 'BBCA:IDX', b: 'AAPL:US', r: 0.08),
        (a: 'TLKM:IDX', b: 'AAPL:US', r: -0.14),
      ],
      scenarios: [
        StressScenario(
          id: 'mild',
          label: 'Koreksi Ringan',
          description: 'Koreksi normal pasar',
          drops: (idx: -10, us: -8, crypto: -15),
        ),
        StressScenario(
          id: 'bear',
          label: 'Bear Market',
          description: 'Penurunan signifikan',
          drops: (idx: -25, us: -20, crypto: -40),
        ),
        StressScenario(
          id: 'crisis',
          label: 'Krisis 2020',
          description: 'Seperti crash COVID Mar-2020',
          drops: (idx: -38, us: -34, crypto: -50),
        ),
        StressScenario(
          id: 'custom',
          label: 'Kustom',
          description: 'Atur sendiri persentase',
          drops: (idx: 0, us: 0, crypto: 0),
        ),
      ],
      historyDays: 22,
      portfolio: PortfolioRisk(
        sharpe: 0.84,
        riskFreePercent: 6,
        betaIhsg: 0.92,
        betaSp500: 0.31,
        betaBtc: 0.18,
        days: 180,
      ),
    );
  }
}
