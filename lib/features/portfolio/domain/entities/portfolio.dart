import 'package:arah/core/domain/money.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:equatable/equatable.dart';

class Portfolio extends Equatable {
  const Portfolio({required this.positions, this.priceAsOf, this.usdToIdr});

  final List<Position> positions;

  /// Waktu harga diambil; harga bisa dari cache, jadi jangan dilabeli "live".
  final DateTime? priceAsOf;

  /// Kurs server (`asOf.usdToIdr` /api/summary) untuk alat yang butuh total rupiah, mis. kalkulator.
  final double? usdToIdr;

  /// Nilai posisi dalam rupiah: nilai pasar, atau modal bila harga belum ada (rumus web & server).
  double valueIdr(Position p) =>
      (p.marketValue ?? p.costBasis).amount * (p.currency == Currency.idr ? 1 : (usdToIdr ?? 0));

  double get totalValueIdr => positions.fold(0, (s, p) => s + valueIdr(p));

  /// Mata uang yang ada di portofolio. Total tidak dicampur lintas mata uang.
  List<Currency> get currencies => {for (final p in positions) p.currency}.toList();

  /// Total nilai pasar per mata uang; `null` jika ada harga yang belum tersedia.
  Money? marketValue(Currency currency) => _sum(currency, (p) => p.marketValue);

  Money? unrealizedPnl(Currency currency) => _sum(currency, (p) => p.unrealizedPnl);

  /// Posisi yang belum punya harga terakhir (tidak masuk [pricedTotals]).
  List<Position> get unpriced => positions.where((p) => p.marketValue == null).toList();

  /// Total posisi yang sudah punya harga untuk satu mata uang; `null` bila tidak ada.
  ({Money value, Money pnl, double? percent, int count})? pricedTotals(Currency currency) {
    final priced = positions.where((p) => p.currency == currency && p.marketValue != null).toList();
    if (priced.isEmpty) return null;
    final value = priced.fold(0.0, (s, p) => s + p.marketValue!.amount);
    final cost = priced.fold(0.0, (s, p) => s + p.costBasis.amount);
    return (
      value: Money(value, currency),
      pnl: Money(value - cost, currency),
      percent: cost == 0 ? null : (value - cost) / cost * 100,
      count: priced.length,
    );
  }

  Money? _sum(Currency currency, Money? Function(Position p) pick) {
    var total = 0.0;
    for (final p in positions.where((p) => p.currency == currency)) {
      final value = pick(p);
      if (value == null) return null;
      total += value.amount;
    }
    return Money(total, currency);
  }

  @override
  List<Object?> get props => [positions, priceAsOf, usdToIdr];
}
