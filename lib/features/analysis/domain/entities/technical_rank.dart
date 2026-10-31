import 'package:equatable/equatable.dart';

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
  List<Object?> get props => [symbol, exchange, score, emaTrend, macdCross, rsi, volumeSurge, price, updatedAt];
}

class TechnicalRanking extends Equatable {
  const TechnicalRanking({required this.items, this.missing = const []});
  final List<RankItem> items;

  /// `KODE:BURSA` yang belum punya sinyal (baru ditambah / histori belum cukup).
  final List<String> missing;

  @override
  List<Object?> get props => [items, missing];
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
  // Pendukung dulu, lalu netral, lalu peringatan.
  return out..sort((a, b) => a.tone.index.compareTo(b.tone.index));
}
