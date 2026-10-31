import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/analysis/domain/entities/technical_rank.dart';

abstract interface class TechnicalRankRemoteDataSource {
  Future<TechnicalRanking> fetch();
}

double? _n(Object? v) => (v as num?)?.toDouble();

/// `GET /api/signals/ranking`: sinyal posisi aktif ∪ watchlist (data cron pagi).
class TechnicalRankApiDataSource implements TechnicalRankRemoteDataSource {
  const TechnicalRankApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<TechnicalRanking> fetch() async {
    final d = await _api.get('/api/signals/ranking') as Map<String, dynamic>;
    return TechnicalRanking(
      items: [
        for (final i in (d['items'] as List<dynamic>).cast<Map<String, dynamic>>())
          RankItem(
            symbol: i['stockCode'] as String,
            exchange: i['exchange'] as String,
            inPortfolio: i['inPortfolio'] as bool,
            inWatchlist: i['inWatchlist'] as bool,
            positionId: i['positionId'] as String?,
            score: (i['score'] as num).toInt(),
            label: i['label'] as String,
            emaTrend: i['emaTrend'] as String,
            macdCross: i['macdCross'] as String,
            volumeSurge: i['volumeSurge'] as bool? ?? false,
            updatedAt: DateTime.parse(i['updatedAt'] as String),
            rsi: _n(i['rsi']),
            price: _n(i['price']),
            week52High: _n(i['week52High']),
            week52Low: _n(i['week52Low']),
            scoreWeekAgo: (i['scoreWeekAgo'] as num?)?.toInt(),
            pnlPct: _n(i['pnlPct']),
            relativeStrength: switch (i['relativeStrength']) {
              final Map<String, dynamic> rs => (
                benchmark: rs['benchmark'] as String,
                days: (rs['days'] as num).toInt(),
                stockPct: _n(rs['stockPct'])!,
                benchmarkPct: _n(rs['benchmarkPct'])!,
              ),
              _ => null,
            },
          ),
      ],
      missing: (d['missing'] as List<dynamic>).cast<String>(),
      backtest: switch (d['backtest']) {
        final Map<String, dynamic> b => ScoreBacktest(
          horizonDays: (b['horizonDays'] as num).toInt(),
          tickers: (b['tickers'] as num).toInt(),
          groups: [
            for (final g in (b['groups'] as List<dynamic>).cast<Map<String, dynamic>>())
              (
                score: (g['score'] as num?)?.toInt(),
                samples: (g['samples'] as num).toInt(),
                avgReturnPct: _n(g['avgReturnPct']),
                winRatePct: _n(g['winRatePct']),
              ),
          ],
        ),
        _ => null,
      },
    );
  }
}

/// Fixture: posisi galeri (BBCA, TLKM, AAPL; BTC tanpa sinyal) + watchlist (TLKM, NVDA).
class TechnicalRankFixtureDataSource implements TechnicalRankRemoteDataSource {
  @override
  Future<TechnicalRanking> fetch() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day, 8);
    return TechnicalRanking(
      items: [
        RankItem(
          symbol: 'BBCA',
          exchange: 'IDX',
          inPortfolio: true,
          inWatchlist: false,
          positionId: 'bbca',
          score: 4,
          label: 'Sinyal Beli',
          emaTrend: 'bullish',
          macdCross: 'bullish cross',
          volumeSurge: true,
          updatedAt: at,
          rsi: 58,
          price: 9500,
          week52High: 10200,
          week52Low: 8400,
          scoreWeekAgo: 3,
          pnlPct: 8.4,
          relativeStrength: (benchmark: 'IHSG', days: 90, stockPct: 6.2, benchmarkPct: 1.8),
        ),
        RankItem(
          symbol: 'AAPL',
          exchange: 'US',
          inPortfolio: true,
          inWatchlist: false,
          positionId: 'aapl',
          score: 4,
          label: 'Sinyal Beli',
          emaTrend: 'bullish',
          macdCross: '—',
          volumeSurge: false,
          updatedAt: at,
          rsi: 72,
          price: 185.5,
          week52High: 188,
          week52Low: 150,
        ),
        RankItem(
          symbol: 'NVDA',
          exchange: 'US',
          inPortfolio: false,
          inWatchlist: true,
          score: 3,
          label: 'Neutral',
          emaTrend: 'neutral',
          macdCross: '—',
          volumeSurge: false,
          updatedAt: at,
          rsi: 49,
        ),
        RankItem(
          symbol: 'TLKM',
          exchange: 'IDX',
          inPortfolio: true,
          inWatchlist: true,
          positionId: 'tlkm',
          score: 2,
          label: 'Sinyal Jual',
          emaTrend: 'bearish',
          macdCross: 'bearish cross',
          volumeSurge: false,
          updatedAt: at,
          rsi: 28,
          price: 2950,
          week52High: 4250,
          week52Low: 2650,
          scoreWeekAgo: 3,
          pnlPct: -12.5,
          relativeStrength: (benchmark: 'IHSG', days: 90, stockPct: -9.4, benchmarkPct: 1.8),
        ),
      ],
      missing: const ['BTC:CRYPTO'],
      backtest: const ScoreBacktest(
        horizonDays: 20,
        tickers: 4,
        groups: [
          (score: null, samples: 820, avgReturnPct: 0.9, winRatePct: 52),
          (score: 1, samples: 12, avgReturnPct: -3.1, winRatePct: 33),
          (score: 2, samples: 140, avgReturnPct: -1.2, winRatePct: 41),
          (score: 3, samples: 480, avgReturnPct: 0.8, winRatePct: 52),
          (score: 4, samples: 170, avgReturnPct: 2.6, winRatePct: 63),
          (score: 5, samples: 18, avgReturnPct: 3.4, winRatePct: 67),
        ],
      ),
    );
  }
}
