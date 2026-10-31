import 'package:arah/core/format/formatters.dart';
import 'package:equatable/equatable.dart';

/// Perubahan % saham vs indeks bursanya dalam [days] hari terakhir.
typedef RelativeStrength = ({String benchmark, int days, double stockPct, double benchmarkPct});

/// Sinyal teknikal satu ticker milik user (`/api/signals/ranking`), dari cron pagi.
class RankItem extends Equatable {
  const RankItem({
    required this.symbol,
    required this.exchange,
    required this.inPortfolio,
    required this.inWatchlist,
    required this.score,
    required this.label,
    required this.emaTrend,
    required this.macdCross,
    required this.volumeSurge,
    required this.updatedAt,
    this.positionId,
    this.rsi,
    this.price,
    this.week52High,
    this.week52Low,
    this.scoreWeekAgo,
    this.pnlPct,
    this.relativeStrength,
  });

  final String symbol;

  /// Kode bursa backend: IDX / US / CRYPTO.
  final String exchange;
  final bool inPortfolio;
  final bool inWatchlist;

  /// Untuk membuka detail posisi; `null` bila hanya di watchlist.
  final String? positionId;

  /// 1 (jual kuat) – 5 (beli kuat).
  final int score;
  final String label;

  /// `bullish` / `bearish` / `neutral`.
  final String emaTrend;

  /// `bullish cross` / `bearish cross` / `—`.
  final String macdCross;
  final bool volumeSurge;
  final DateTime updatedAt;
  final double? rsi;
  final double? price;
  final double? week52High;
  final double? week52Low;

  /// Skor 5 hari bursa lalu (dari histori harga); `null` bila histori kurang.
  final int? scoreWeekAgo;

  /// Untung/rugi posisi gabungan semua broker (%); `null` untuk watchlist atau harga belum ada.
  final double? pnlPct;
  final RelativeStrength? relativeStrength;

  /// Selisih poin persen terhadap indeks (+ = lebih kuat dari pasar).
  double? get relativeGap => switch (relativeStrength) {
    final rs? => rs.stockPct - rs.benchmarkPct,
    null => null,
  };

  /// Posisi harga di rentang 52 minggu, 0 (terendah) – 100 (tertinggi); `null` bila data kurang.
  double? get week52Position {
    final hi = week52High, lo = week52Low, p = price;
    if (hi == null || lo == null || p == null || hi <= lo) return null;
    return ((p - lo) / (hi - lo) * 100).clamp(0, 100).toDouble();
  }

  /// Pemecah seri untuk skor yang sama (lihat [rankItems]).
  int get tieBreak =>
      switch (emaTrend) {
        'bullish' => 2,
        'neutral' => 1,
        _ => 0,
      } +
      switch (macdCross) {
        'bullish cross' => 1,
        'bearish cross' => -1,
        _ => 0,
      } +
      switch (rsi) {
        final r? when r >= 40 && r <= 65 => 1, // momentum sehat
        final r? when r > 70 => -1, // jenuh beli, rawan koreksi
        _ => 0,
      } +
      (volumeSurge && emaTrend == 'bullish' ? 1 : 0);

  @override
  List<Object?> get props => [
    symbol,
    exchange,
    score,
    emaTrend,
    macdCross,
    rsi,
    volumeSurge,
    price,
    updatedAt,
    scoreWeekAgo,
    pnlPct,
    relativeStrength,
  ];
}

/// Hasil uji skor satu kelompok: [score] `null` = semua hari.
typedef BacktestGroup = ({int? score, int samples, double? avgReturnPct, double? winRatePct});

/// Uji skor: return [horizonDays] hari bursa setelah tiap skor, gabungan [tickers] ticker milik user.
class ScoreBacktest extends Equatable {
  const ScoreBacktest({required this.horizonDays, required this.tickers, required this.groups});
  final int horizonDays;
  final int tickers;
  final List<BacktestGroup> groups;

  BacktestGroup? group(int? score) => groups.where((g) => g.score == score).firstOrNull;

  /// Rata-rata return gabungan untuk beberapa skor (dibobot jumlah sampel).
  double? averageOf(List<int> scores) {
    final gs = groups.where((g) => scores.contains(g.score) && g.avgReturnPct != null);
    final n = gs.fold(0, (s, g) => s + g.samples);
    return n == 0 ? null : gs.fold(0.0, (s, g) => s + g.avgReturnPct! * g.samples) / n;
  }

  /// Kesimpulan awam; butuh cukup sampel di kedua sisi supaya tidak menyimpulkan dari segelintir hari.
  String get verdict {
    const minSamples = 30;
    int count(List<int> s) => groups.where((g) => s.contains(g.score)).fold(0, (a, g) => a + g.samples);
    final high = averageOf([4, 5]), low = averageOf([1, 2]);
    if (high == null || low == null || count([4, 5]) < minSamples || count([1, 2]) < minSamples) {
      return 'Data belum cukup untuk menilai skor (perlu lebih banyak hari bertanda skor tinggi & rendah).';
    }
    if (high > low + 1) {
      return 'Di saham-sahammu, skor tinggi (4–5) diikuti rata-rata ${Fmt.percent(high)} '
          'dibanding ${Fmt.percent(low)} untuk skor rendah (1–2) — skor cukup membedakan.';
    }
    return 'Di saham-sahammu, skor tinggi (${Fmt.percent(high)}) tidak jelas lebih baik dari skor rendah '
        '(${Fmt.percent(low)}) — jangan terlalu mengandalkan skor.';
  }

  @override
  List<Object?> get props => [horizonDays, tickers, groups];
}

class TechnicalRanking extends Equatable {
  const TechnicalRanking({required this.items, this.missing = const [], this.backtest});
  final List<RankItem> items;

  /// `KODE:BURSA` yang belum punya sinyal (baru ditambah / histori belum cukup).
  final List<String> missing;
  final ScoreBacktest? backtest;

  @override
  List<Object?> get props => [items, missing, backtest];
}

/// Urutan teknikal terbaik: skor sinyal (1–5) dulu, lalu [RankItem.tieBreak], lalu kode (stabil).
List<RankItem> rankItems(Iterable<RankItem> items) => [...items]
  ..sort(
    (a, b) => b.score != a.score
        ? b.score.compareTo(a.score)
        : b.tieBreak != a.tieBreak
        ? b.tieBreak.compareTo(a.tieBreak)
        : a.symbol.compareTo(b.symbol),
  );

enum ReasonTone { positive, neutral, negative }

/// Alasan dalam bahasa awam, yang mendukung dulu lalu yang perlu diwaspadai. Informasi, bukan saran.
List<({String text, ReasonTone tone})> rankReasons(RankItem i) {
  final out = <({String text, ReasonTone tone})>[];
  switch (i.emaTrend) {
    case 'bullish':
      out.add((text: 'Tren naik: harga di atas EMA20 & EMA50', tone: ReasonTone.positive));
    case 'bearish':
      out.add((text: 'Tren turun: harga di bawah EMA20 & EMA50', tone: ReasonTone.negative));
    default:
      out.add((text: 'Belum ada tren jelas', tone: ReasonTone.neutral));
  }
  switch (i.macdCross) {
    case 'bullish cross':
      out.add((text: 'MACD baru persilangan naik (momentum menguat)', tone: ReasonTone.positive));
    case 'bearish cross':
      out.add((text: 'MACD baru persilangan turun (momentum melemah)', tone: ReasonTone.negative));
  }
  if (i.volumeSurge) {
    out.add((text: 'Volume melonjak di atas rata-rata', tone: ReasonTone.positive));
  }
  final rsi = i.rsi;
  if (rsi != null) {
    final v = rsi.toStringAsFixed(0);
    out.add(switch (rsi) {
      > 70 => (text: 'RSI $v · jenuh beli, rawan koreksi', tone: ReasonTone.negative),
      < 30 => (text: 'RSI $v · jenuh jual, bisa memantul atau terus turun', tone: ReasonTone.neutral),
      >= 40 && <= 65 => (text: 'RSI $v · momentum sehat', tone: ReasonTone.positive),
      _ => (text: 'RSI $v · netral', tone: ReasonTone.neutral),
    });
  }
  final pos = i.week52Position;
  if (pos != null && pos >= 85) {
    out.add((text: 'Dekat harga tertinggi 52 minggu', tone: ReasonTone.neutral));
  } else if (pos != null && pos <= 15) {
    out.add((text: 'Dekat harga terendah 52 minggu', tone: ReasonTone.neutral));
  }
  if (i.relativeStrength case final rs?) {
    final gap = i.relativeGap!;
    final text =
        '${Fmt.percent(rs.stockPct)} vs ${rs.benchmark} ${Fmt.percent(rs.benchmarkPct)} (${rs.days ~/ 30} bulan)';
    out.add(switch (gap) {
      >= 3 => (text: 'Lebih kuat dari pasar: $text', tone: ReasonTone.positive),
      <= -3 => (text: 'Lebih lemah dari pasar: $text', tone: ReasonTone.negative),
      _ => (text: 'Sejalan dengan pasar: $text', tone: ReasonTone.neutral),
    });
  }
  if (i.pnlPct case final pnl?) {
    final p = Fmt.percent(pnl);
    out.add(switch ((pnl >= 0, i.emaTrend)) {
      (true, 'bearish') => (text: 'Posisimu untung $p, tapi tren turun', tone: ReasonTone.negative),
      (false, 'bearish') => (text: 'Posisimu rugi $p dan tren masih turun', tone: ReasonTone.negative),
      (false, 'bullish') => (text: 'Posisimu rugi $p, tren sudah naik', tone: ReasonTone.neutral),
      (true, _) => (text: 'Posisimu untung $p', tone: ReasonTone.neutral),
      (false, _) => (text: 'Posisimu rugi $p', tone: ReasonTone.neutral),
    });
  }
  // Pendukung dulu, lalu netral, lalu peringatan.
  return out..sort((a, b) => a.tone.index.compareTo(b.tone.index));
}
