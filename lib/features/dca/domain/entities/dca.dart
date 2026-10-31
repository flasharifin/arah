import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:equatable/equatable.dart';

/// Rencana beli berkala. Nominal dalam mata uang posisinya; API rencana tidak menyertakan
/// mata uang, jadi ditampilkan sebagai angka biasa.
class DcaPlan extends Equatable {
  const DcaPlan({
    required this.id,
    required this.portfolioId,
    required this.symbol,
    required this.targetPrice,
    required this.budget,
    required this.frequency,
    required this.isActive,
    this.nextDate,
  });

  final String id;
  final String portfolioId;
  final String symbol;
  final double targetPrice;
  final double budget;

  /// `weekly` | `monthly` | `custom`.
  final String frequency;
  final bool isActive;
  final DateTime? nextDate;

  String get frequencyLabel => switch (frequency) {
    'weekly' => 'Mingguan',
    'monthly' => 'Bulanan',
    _ => 'Kustom',
  };

  @override
  List<Object?> get props => [id, portfolioId, symbol, targetPrice, budget, frequency, isActive, nextDate];
}

/// Pelaksanaan DCA yang tercatat (otomatis menambah lot & menghitung ulang harga rata-rata posisi).
class DcaRecord extends Equatable {
  const DcaRecord({
    required this.id,
    required this.symbol,
    required this.quantity,
    required this.price,
    required this.total,
    required this.date,
  });

  final String id;
  final String symbol;

  /// Lot untuk IDX, unit untuk US/Crypto.
  final double quantity;
  final double price;
  final double total;
  final DateTime date;

  @override
  List<Object?> get props => [id, symbol, quantity, price, total, date];
}

class DcaOverview extends Equatable {
  const DcaOverview({required this.plans, required this.records, this.positions = const []});
  final List<DcaPlan> plans;
  final List<DcaRecord> records;

  /// Posisi portofolio: pilihan saat membuat rencana & simulasi, dan sumber mata uang rencana.
  final List<Position> positions;

  Position? positionOf(DcaPlan plan) => positions.where((p) => p.id == plan.portfolioId).firstOrNull;

  DcaOverview withPositions(List<Position> positions) =>
      DcaOverview(plans: plans, records: records, positions: positions);

  @override
  List<Object?> get props => [plans, records, positions];
}

/// Isian buat/ubah rencana. Saat ubah, posisi tidak bisa diganti (API hanya menerima field lain).
class DcaPlanDraft {
  const DcaPlanDraft({
    required this.portfolioId,
    required this.symbol,
    required this.targetPrice,
    required this.budget,
    required this.frequency,
    required this.isActive,
    this.nextDate,
  });

  final String portfolioId;
  final String symbol;
  final double targetPrice;
  final double budget;
  final String frequency;
  final bool isActive;
  final DateTime? nextDate;
}

class DcaSimulation extends Equatable {
  const DcaSimulation({
    required this.newAvgPrice,
    required this.totalQuantity,
    required this.additionalCost,
    required this.totalCost,
    this.marketGap,
  });

  final double newAvgPrice;

  /// Lot (IDX) / unit (US, Crypto) setelah pembelian tambahan.
  final double totalQuantity;
  final double additionalCost;
  final double totalCost;

  /// Harga rata-rata baru − harga pasar; positif = masih rugi. `null` bila harga pasar tidak tersedia.
  final double? marketGap;

  @override
  List<Object?> get props => [newAvgPrice, totalQuantity, additionalCost, totalCost, marketGap];
}

/// Rumus sama dengan simulasi DCA di web (calcAvgPrice): rata-rata tertimbang per lot/unit.
DcaSimulation simulateDca(Position position, {required double quantity, required double price}) {
  final totalQuantity = position.quantity + quantity;
  final newAvgPrice = totalQuantity == 0
      ? 0.0
      : (position.quantity * position.avgPrice.amount + quantity * price) / totalQuantity;
  final additionalCost = quantity * position.exchange.unitsPerQuantity * price;
  final last = position.lastPrice;
  return DcaSimulation(
    newAvgPrice: newAvgPrice,
    totalQuantity: totalQuantity,
    additionalCost: additionalCost,
    totalCost: position.costBasis.amount + additionalCost,
    marketGap: last == null ? null : newAvgPrice - last.amount,
  );
}

/// Isian "Catat pelaksanaan". [requestId] dibuat sekali per form: kirim ulang tidak mencatat dua kali.
class DcaExecution {
  const DcaExecution({
    required this.plan,
    required this.quantity,
    required this.price,
    required this.date,
    required this.requestId,
  });

  final DcaPlan plan;
  final double quantity;
  final double price;
  final DateTime date;
  final String requestId;
}
