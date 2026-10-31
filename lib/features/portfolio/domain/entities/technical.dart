import 'package:arah/core/format/formatters.dart';
import 'package:equatable/equatable.dart';

/// Satu hari data teknikal (`priceHistory` di `/api/portfolio/[id]/detail`), harga dalam mata uang posisi.
/// Indikator `null` = belum cukup data pemanasan.
class TaPoint extends Equatable {
  const TaPoint({
    required this.date,
    required this.close,
    required this.volume,
    this.ema20,
    this.ema50,
    this.rsi,
    this.macdLine,
    this.macdSignal,
    this.macdHist,
    this.volumeMa20,
    this.atr,
    this.score,
  });

  final DateTime date;
  final double close;
  final double volume;
  final double? ema20;
  final double? ema50;
  final double? rsi;
  final double? macdLine;
  final double? macdSignal;
  final double? macdHist;
  final double? volumeMa20;

  /// Average True Range 14 hari, dalam satuan harga.
  final double? atr;

  /// Skor sinyal 1–5 hari itu (aturan sama dengan sinyal harian, tanpa Fear & Greed).
  final int? score;

  @override
  List<Object?> get props => [
    date,
    close,
    volume,
    ema20,
    ema50,
    rsi,
    macdLine,
    macdSignal,
    macdHist,
    volumeMa20,
    atr,
    score,
  ];
}

/// Sinyal gabungan yang dihitung cron briefing pagi (`SignalCache`).
class TaSignal extends Equatable {
  const TaSignal({
    required this.score,
    required this.label,
    required this.emaTrend,
    required this.macdCross,
    required this.volumeSurge,
    required this.updatedAt,
    this.fearGreed,
  });

  /// 1 (jual kuat) – 5 (beli kuat).
  final int score;
  final String label;

  /// `bullish` / `bearish` / `neutral`.
  final String emaTrend;

  /// `bullish cross` / `bearish cross` / `—`.
  final String macdCross;
  final bool volumeSurge;
  final DateTime updatedAt;

  /// Fear & Greed kripto (0–100), hanya untuk posisi kripto.
  final int? fearGreed;

  @override
  List<Object?> get props => [score, label, emaTrend, macdCross, volumeSurge, updatedAt, fearGreed];
}

class TechnicalAnalysis extends Equatable {
  const TechnicalAnalysis({required this.points, this.signal});

  /// Urut tanggal naik, maksimal 1 tahun.
  final List<TaPoint> points;

  /// `null` = cron belum menghitung sinyal untuk ticker ini.
  final TaSignal? signal;

  TaPoint? get last => points.isEmpty ? null : points.last;

  @override
  List<Object?> get props => [points, signal];
}

/// Arti satu indikator dalam bahasa awam; [tone] untuk warna penanda (selalu disertai teks).
typedef TaReading = ({String title, String value, String meaning, TaTone tone});

enum TaTone { positive, neutral, negative }

/// Tren dari posisi harga terhadap EMA20 & EMA50 (aturan sama dengan `calcEMATrend` backend).
TaReading? trendReading(TaPoint p) {
  final e20 = p.ema20, e50 = p.ema50;
  if (e20 == null || e50 == null) return null;
  final (meaning, tone) = p.close > e20 && e20 > e50
      ? ('Tren naik: harga di atas EMA20, EMA20 di atas EMA50', TaTone.positive)
      : p.close < e20 && e20 < e50
      ? ('Tren turun: harga di bawah EMA20, EMA20 di bawah EMA50', TaTone.negative)
      : ('Belum ada tren jelas (harga & EMA bersilangan)', TaTone.neutral);
  return (title: 'Tren EMA', value: e20 >= e50 ? 'EMA20 > EMA50' : 'EMA20 < EMA50', meaning: meaning, tone: tone);
}

/// RSI 14 hari: < 30 jenuh jual, > 70 jenuh beli.
TaReading? rsiReading(TaPoint p) {
  final rsi = p.rsi;
  if (rsi == null) return null;
  final (meaning, tone) = rsi < 30
      // Netral (bukan hijau/merah): ekstrem RSI bukan sinyal beli/jual tersendiri.
      ? ('Jenuh jual (oversold) — sering diikuti pantulan, tapi bisa terus turun', TaTone.neutral)
      : rsi > 70
      ? ('Jenuh beli (overbought) — rawan koreksi', TaTone.neutral)
      : ('Netral (30–70)', TaTone.neutral);
  return (title: 'RSI (14)', value: rsi.toStringAsFixed(1).replaceAll('.', ','), meaning: meaning, tone: tone);
}

/// MACD: histogram positif = momentum naik; persilangan terbaru dari sinyal cron.
TaReading? macdReading(TaPoint p, TaSignal? signal) {
  final hist = p.macdHist;
  if (hist == null) return null;
  final cross = switch (signal?.macdCross) {
    'bullish cross' => ' · baru persilangan naik',
    'bearish cross' => ' · baru persilangan turun',
    _ => '',
  };
  return (
    title: 'MACD',
    value: hist >= 0 ? 'Histogram +' : 'Histogram −',
    meaning: '${hist >= 0 ? 'Momentum menguat' : 'Momentum melemah'}$cross',
    tone: hist >= 0 ? TaTone.positive : TaTone.negative,
  );
}

/// Volume hari terakhir dibanding rata-rata 20 hari.
TaReading? volumeReading(TaPoint p) {
  final ma = p.volumeMa20;
  if (ma == null || ma <= 0) return null;
  final ratio = p.volume / ma;
  final x = '${ratio.toStringAsFixed(1).replaceAll('.', ',')}× rata-rata 20 hari';
  final (meaning, tone) = ratio >= 1.5
      ? ('Volume tinggi — pergerakan harga lebih bisa dipercaya', TaTone.positive)
      : ratio <= 0.7
      ? ('Volume sepi — pergerakan harga kurang meyakinkan', TaTone.neutral)
      : ('Volume normal', TaTone.neutral);
  return (title: 'Volume', value: x, meaning: meaning, tone: tone);
}

/// Volatilitas dari ATR 14: rata-rata rentang gerak harian, plus patokan stop umum 2×ATR di bawah harga.
TaReading? volatilityReading(TaPoint p) {
  final atr = p.atr;
  if (atr == null || p.close <= 0) return null;
  final pct = atr / p.close * 100;
  final stop = p.close - 2 * atr;
  return (
    title: 'Volatilitas (ATR 14)',
    value: '±${pct.toStringAsFixed(1).replaceAll('.', ',')}%/hari',
    meaning:
        '${pct >= 4
            ? 'Bergerak liar'
            : pct <= 1.5
            ? 'Bergerak tenang'
            : 'Gerak harian wajar'} · patokan stop umum 2×ATR di bawah harga: ${Fmt.number(stop > 0 ? stop.round() : 0)}',
    tone: TaTone.neutral,
  );
}

/// Untung/rugi posisimu dibaca bersama tren EMA. Informasi, bukan saran beli/jual.
TaReading? positionReading(double? pnlPercent, TaPoint p) {
  final pnl = pnlPercent;
  final trend = trendReading(p);
  if (pnl == null || trend == null) return null;
  final up = trend.tone == TaTone.positive, down = trend.tone == TaTone.negative;
  final (meaning, tone) = pnl >= 0
      ? up
            ? ('Untung dan tren masih naik', TaTone.positive)
            : down
            ? ('Untung, tapi tren mulai turun — pantau keuntunganmu', TaTone.negative)
            : ('Untung, tren belum jelas', TaTone.neutral)
      : up
      ? ('Masih rugi, tapi tren sudah naik', TaTone.positive)
      : down
      ? ('Rugi dan tren masih turun — cek lagi alasan awal membeli', TaTone.negative)
      : ('Rugi, tren belum jelas', TaTone.neutral);
  return (title: 'Posisimu', value: Fmt.percent(pnl), meaning: meaning, tone: tone);
}
