import 'package:arah/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// Biaya tersembunyi satu posisi (`/api/portfolio/invisible-cost`), nominal dalam mata uang posisi.
class InvisibleCost extends Equatable {
  const InvisibleCost({
    required this.symbol,
    required this.exchange,
    required this.costBasis,
    required this.holdDays,
    required this.returnPercent,
    required this.ihsgPercent,
    required this.opportunityCost,
    required this.inflation,
    required this.isZombie,
  });

  final String symbol;
  final String exchange;
  final Money costBasis;
  final int holdDays;

  /// Harga terakhir vs harga rata-rata.
  final double returnPercent;

  /// IHSG majemuk sejak tanggal beli.
  final double ihsgPercent;

  /// Selisih tertinggal dari IHSG × modal; 0 bila mengungguli IHSG.
  final Money opportunityCost;

  /// Erosi daya beli modal: 3,5%/tahun × lama pegang.
  final Money inflation;

  /// Bergerak < ±7% selama > 60 hari.
  final bool isZombie;

  Money get total => Money(opportunityCost.amount + inflation.amount, costBasis.currency);

  @override
  List<Object?> get props => [
    symbol,
    exchange,
    costBasis,
    holdDays,
    returnPercent,
    ihsgPercent,
    opportunityCost,
    inflation,
    isZombie,
  ];
}

enum TimelineKind { buy, sell, dividend }

class TimelineEvent extends Equatable {
  const TimelineEvent({required this.date, required this.kind, required this.label, required this.amount});
  final DateTime date;
  final TimelineKind kind;
  final String label;

  /// Beli = modal, jual = realized PnL, dividen = diterima.
  final Money amount;

  @override
  List<Object?> get props => [date, kind, label, amount];
}

/// `/api/portfolio/wealth-timeline`: nilai porto harian + kejadian investasi (terbaru dulu).
class WealthTimeline extends Equatable {
  const WealthTimeline({required this.points, required this.events});
  final List<({DateTime date, Money value})> points;
  final List<TimelineEvent> events;

  @override
  List<Object?> get props => [points, events];
}
