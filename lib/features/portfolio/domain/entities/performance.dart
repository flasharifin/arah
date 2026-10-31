import 'package:arah/core/domain/money.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:equatable/equatable.dart';

/// Satu baris PnL harian (dicatat cron setiap malam) + perubahan benchmark hari itu, dalam persen.
class DailyPerformance extends Equatable {
  const DailyPerformance({
    required this.date,
    required this.portfolioValue,
    required this.pnl,
    required this.pnlPercent,
    this.ihsgChange,
    this.sp500Change,
  });

  final DateTime date;
  final Money portfolioValue;
  final Money pnl;

  /// Terhadap nilai porto sebelum perubahan hari itu.
  final double pnlPercent;

  /// `null` = bursa tutup / data benchmark belum ada.
  final double? ihsgChange;
  final double? sp500Change;

  @override
  List<Object?> get props => [date, portfolioValue, pnl, pnlPercent, ihsgChange, sp500Change];
}

enum PerformancePeriod {
  week('7H', 7),
  month('1B', 30),
  quarter('3B', 91),
  year('1T', 365);

  const PerformancePeriod(this.label, this.days);
  final String label;
  final int days;

  /// Baris dalam periode ini, dihitung mundur dari [now]. [rows] urut tanggal naik.
  List<T> filter<T>(List<T> rows, DateTime Function(T) dateOf, DateTime now) {
    final from = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    return rows.where((r) => !dateOf(r).isBefore(from)).toList();
  }
}

/// Return kumulatif majemuk per hari, dalam persen: Π(1 + r/100) − 1. Hari `null` (bursa tutup) datar.
/// Rumus sama dengan TWR di tab PnL web; tidak terpengaruh setoran/penarikan modal.
List<double> cumulativeReturn(Iterable<double?> dailyPercent) {
  var product = 1.0;
  return [for (final r in dailyPercent) (product *= 1 + (r ?? 0) / 100) * 100 - 100];
}

/// Satu transaksi jual (realized PnL), dalam mata uang aset.
class SaleRecord extends Equatable {
  const SaleRecord({
    required this.id,
    required this.symbol,
    required this.exchange,
    required this.broker,
    required this.quantity,
    required this.salePrice,
    required this.proceeds,
    required this.realizedPnl,
    required this.realizedPercent,
    required this.date,
    this.note,
  });

  final String id;
  final String symbol;
  final Exchange exchange;
  final String broker;

  /// Lot untuk IDX, unit untuk US/Crypto.
  final double quantity;
  final Money salePrice;
  final Money proceeds;
  final Money realizedPnl;
  final double realizedPercent;
  final DateTime date;
  final String? note;

  Currency get currency => proceeds.currency;

  @override
  List<Object?> get props => [id, symbol, exchange, broker, quantity, salePrice, proceeds, realizedPnl, date, note];
}
