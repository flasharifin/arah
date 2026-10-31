import 'package:arah/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// Posisi dengan selisih harga terakhir vs harga rata-rata beli (bukan return mingguan).
typedef Mover = ({String symbol, String exchange, double percent});

/// S15 — Surat investor mingguan dari `/api/investor-letter` (7 hari terakhir).
class InvestorLetter extends Equatable {
  const InvestorLetter({
    required this.weekStart,
    required this.weekEnd,
    required this.portfolioValue,
    required this.weeklyChange,
    required this.weeklyChangePercent,
    required this.ihsgPercent,
    required this.sp500Percent,
    required this.weekHigh,
    required this.weekLow,
    required this.topGainers,
    required this.topLosers,
    required this.sales,
    required this.dividends,
    required this.positionCount,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final Money portfolioValue;
  final Money weeklyChange;
  final double weeklyChangePercent;
  final double ihsgPercent;
  final double sp500Percent;
  final Money weekHigh;
  final Money weekLow;
  final List<Mover> topGainers;
  final List<Mover> topLosers;

  /// Realized PnL per transaksi dalam mata uang asal (tidak dijumlah lintas mata uang).
  final List<({String symbol, Money realizedPnl, DateTime date})> sales;
  final List<({String symbol, Money received, DateTime? date})> dividends;
  final int positionCount;

  @override
  List<Object?> get props => [
    weekStart,
    weekEnd,
    portfolioValue,
    weeklyChange,
    sales,
    dividends,
    topGainers,
    topLosers,
  ];
}
