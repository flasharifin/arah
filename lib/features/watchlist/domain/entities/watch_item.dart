import 'package:arah/core/domain/money.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:equatable/equatable.dart';

/// Nilai `status` di backend (WatchlistItem.status).
enum WatchStatus {
  observe('observasi', 'Observasi'),
  readyToBuy('siap_beli', 'Siap beli'),
  skip('skip', 'Skip');

  const WatchStatus(this.code, this.label);
  final String code;
  final String label;

  static WatchStatus fromCode(String? code) =>
      values.firstWhere((s) => s.code == code, orElse: () => observe);
}

/// Sinyal teknikal dari cache server (diperbarui morning briefing); bisa belum ada untuk saham baru.
class WatchSignal extends Equatable {
  const WatchSignal({
    required this.score,
    required this.label,
    this.rsi,
    this.trend,
    this.week52High,
    this.week52Low,
    this.week52Position,
  });

  /// 1 (jual kuat) – 5 (beli kuat).
  final int score;
  final String label;
  final double? rsi;

  /// `bullish` | `bearish` | `neutral` (EMA).
  final String? trend;
  final double? week52High;
  final double? week52Low;

  /// Posisi harga dalam rentang 52 minggu, 0 (terendah) – 100 (tertinggi).
  final double? week52Position;

  @override
  List<Object?> get props => [score, label, rsi, trend, week52High, week52Low, week52Position];
}

/// Saham yang diamati. Harga terakhir & jarak ke target bisa tidak tersedia (`null`), bukan nol.
class WatchItem extends Equatable {
  const WatchItem({
    required this.id,
    required this.symbol,
    required this.exchange,
    required this.status,
    this.targetPrice,
    this.lastPrice,
    this.gapPercent,
    this.note,
    this.signal,
  });

  final String id;
  final String symbol;
  final Exchange exchange;
  final WatchStatus status;
  final Money? targetPrice;
  final Money? lastPrice;

  /// (harga − target) / target × 100; negatif = harga sudah di bawah target.
  final double? gapPercent;
  final String? note;
  final WatchSignal? signal;

  @override
  List<Object?> get props => [id, symbol, exchange, status, targetPrice, lastPrice, gapPercent, note, signal];
}

/// Isian form tambah/ubah.
class WatchDraft {
  const WatchDraft({
    required this.symbol,
    required this.exchange,
    required this.status,
    this.targetPrice,
    this.note,
  });

  final String symbol;
  final Exchange exchange;
  final WatchStatus status;
  final double? targetPrice;
  final String? note;
}
