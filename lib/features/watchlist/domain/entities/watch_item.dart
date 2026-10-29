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

  @override
  List<Object?> get props => [id, symbol, exchange, status, targetPrice, lastPrice, gapPercent, note];
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
