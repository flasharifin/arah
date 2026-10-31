import 'dart:math';

import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/portfolio/domain/entities/technical.dart';

abstract interface class TechnicalRemoteDataSource {
  Future<TechnicalAnalysis> fetch(String positionId);
}

double? _n(Object? v) => (v as num?)?.toDouble();

/// `GET /api/portfolio/[id]/detail`: `priceHistory` (1 tahun, indikator per hari) + `signal` dari cron pagi.
class TechnicalApiDataSource implements TechnicalRemoteDataSource {
  const TechnicalApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<TechnicalAnalysis> fetch(String positionId) async {
    final d = await _api.get('/api/portfolio/$positionId/detail') as Map<String, dynamic>;
    final s = d['signal'] as Map<String, dynamic>?;
    return TechnicalAnalysis(
      points: [
        for (final p in (d['priceHistory'] as List<dynamic>).cast<Map<String, dynamic>>())
          TaPoint(
            date: DateTime.parse(p['date'] as String),
            close: _n(p['close'])!,
            volume: _n(p['volume']) ?? 0,
            ema20: _n(p['ema20']),
            ema50: _n(p['ema50']),
            rsi: _n(p['rsi']),
            macdLine: _n(p['macdLine']),
            macdSignal: _n(p['macdSignal']),
            macdHist: _n(p['macdHist']),
            volumeMa20: _n(p['volumeMA20']),
          ),
      ],
      signal: s == null
          ? null
          : TaSignal(
              score: (s['score'] as num).toInt(),
              label: s['label'] as String,
              emaTrend: s['emaTrend'] as String,
              macdCross: s['macdCross'] as String,
              volumeSurge: s['volumeSurge'] as bool? ?? false,
              updatedAt: DateTime.parse(s['updatedAt'] as String),
              fearGreed: (s['fearGreed'] as num?)?.toInt(),
            ),
    );
  }
}

/// Data ilustrasi: ±250 hari bursa deterministik (pola sama untuk semua posisi) dengan indikator dihitung ulang.
class TechnicalFixtureDataSource implements TechnicalRemoteDataSource {
  @override
  Future<TechnicalAnalysis> fetch(String positionId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final today = DateTime.now();
    final days = <DateTime>[
      for (var i = 365; i >= 0; i--)
        if (DateTime(today.year, today.month, today.day - i) case final d when d.weekday <= DateTime.friday) d,
    ];
    // Tren lambat + ayunan harian supaya RSI bergerak realistis (tidak menempel di 0/100).
    final closes = [
      for (var i = 0; i < days.length; i++) 9000 + 600 * sin(i / 18) + i * 3 + 90 * sin(i * 1.7) + 60 * cos(i * 0.9),
    ];
    final volumes = [for (var i = 0; i < days.length; i++) 1e6 + 4e5 * sin(i / 5).abs() + (i % 17 == 0 ? 1.5e6 : 0)];
    final ema20 = _ema(closes, 20), ema50 = _ema(closes, 50), ema12 = _ema(closes, 12), ema26 = _ema(closes, 26);
    final macd = [
      for (var i = 0; i < closes.length; i++) ema12[i] == null || ema26[i] == null ? null : ema12[i]! - ema26[i]!,
    ];
    final macdSignal = _emaNullable(macd, 9);
    final volMa = _ema(volumes, 20);
    final rsi = _rsi(closes, 14);
    return TechnicalAnalysis(
      points: [
        for (var i = 0; i < days.length; i++)
          TaPoint(
            date: days[i],
            close: closes[i],
            volume: volumes[i],
            ema20: ema20[i],
            ema50: ema50[i],
            rsi: rsi[i],
            macdLine: macd[i],
            macdSignal: macdSignal[i],
            macdHist: macd[i] == null || macdSignal[i] == null ? null : macd[i]! - macdSignal[i]!,
            volumeMa20: volMa[i],
          ),
      ],
      signal: TaSignal(
        score: 4,
        label: 'Sinyal Beli',
        emaTrend: 'bullish',
        macdCross: '—',
        volumeSurge: false,
        updatedAt: DateTime(today.year, today.month, today.day, 8),
      ),
    );
  }

  static List<double?> _ema(List<double> v, int period) => _emaNullable(v, period);

  static List<double?> _emaNullable(List<double?> v, int period) {
    final out = List<double?>.filled(v.length, null);
    final k = 2 / (period + 1);
    double? prev;
    var count = 0;
    var sum = 0.0;
    for (var i = 0; i < v.length; i++) {
      final x = v[i];
      if (x == null) continue;
      if (prev == null) {
        sum += x;
        if (++count == period) out[i] = prev = sum / period;
      } else {
        out[i] = prev = x * k + prev * (1 - k);
      }
    }
    return out;
  }

  static List<double?> _rsi(List<double> c, int period) {
    final out = List<double?>.filled(c.length, null);
    for (var i = period; i < c.length; i++) {
      var gain = 0.0, loss = 0.0;
      for (var j = i - period + 1; j <= i; j++) {
        final d = c[j] - c[j - 1];
        d >= 0 ? gain += d : loss -= d;
      }
      out[i] = loss == 0 ? 100 : 100 - 100 / (1 + gain / loss);
    }
    return out;
  }
}
