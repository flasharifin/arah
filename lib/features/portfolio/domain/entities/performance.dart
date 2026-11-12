import 'package:arah/core/domain/money.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// Satu baris PnL harian (dicatat cron setiap malam) + perubahan benchmark hari itu, dalam persen.
class DailyPerformance extends Equatable {
  const DailyPerformance({
    required this.date,
    required this.portfolioValue,
    required this.pnl,
    required this.pnlPercent,
    this.ihsgChange,
    this.sp500Change,
    this.btcChange,
  });

  final DateTime date;
  final Money portfolioValue;
  final Money pnl;

  /// Terhadap nilai porto sebelum perubahan hari itu.
  final double pnlPercent;

  /// `null` = bursa tutup / data benchmark belum ada.
  final double? ihsgChange;
  final double? sp500Change;
  final double? btcChange;

  @override
  List<Object?> get props => [date, portfolioValue, pnl, pnlPercent, ihsgChange, sp500Change, btcChange];
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

enum PerformanceGranularity {
  month('Bulan'),
  quarter('Kuartal'),
  year('Tahun');

  const PerformanceGranularity(this.label);
  final String label;

  /// Hari pertama bulan/kuartal/tahun kalender yang memuat [d].
  DateTime startOf(DateTime d) => switch (this) {
    month => DateTime(d.year, d.month),
    quarter => DateTime(d.year, (d.month - 1) ~/ 3 * 3 + 1),
    year => DateTime(d.year),
  };

  /// `Okt 2026`, `Q4 2026`, `2026`.
  String labelOf(DateTime start) => switch (this) {
    month => DateFormat('MMM yyyy', 'id').format(start),
    quarter => 'Q${(start.month - 1) ~/ 3 + 1} ${start.year}',
    year => '${start.year}',
  };
}

/// Ringkasan satu periode kalender dari baris harian.
class PeriodPerformance extends Equatable {
  const PeriodPerformance({
    required this.start,
    required this.endValue,
    required this.pnl,
    required this.returnPercent,
    this.ihsgReturn,
    this.sp500Return,
    this.btcReturn,
  });

  final DateTime start;

  /// Nilai porto di hari tercatat terakhir; ikut naik saat ada top up.
  final Money endValue;

  /// Jumlah PnL harian: hanya pergerakan harga, top up tidak terhitung.
  final Money pnl;

  /// Return majemuk harian (TWR) dalam periode, dalam persen.
  final double returnPercent;

  /// Return indeks dalam periode yang sama; `null` = tidak ada data indeks sama sekali.
  final double? ihsgReturn;
  final double? sp500Return;
  final double? btcReturn;

  @override
  List<Object?> get props => [start, endValue, pnl, returnPercent, ihsgReturn, sp500Return, btcReturn];
}

/// Kelompokkan [rows] (urut tanggal naik) per periode, terlama dulu.
/// Sengaja bukan `/api/pnl/monthly`: `totalPnl` di sana = nilai akhir − nilai awal, sehingga top up terbaca profit.
List<PeriodPerformance> groupByPeriod(List<DailyPerformance> rows, PerformanceGranularity granularity) {
  final groups = <DateTime, List<DailyPerformance>>{};
  for (final r in rows) {
    (groups[granularity.startOf(r.date)] ??= []).add(r);
  }
  double? benchmark(List<DailyPerformance> days, double? Function(DailyPerformance) changeOf) =>
      days.any((r) => changeOf(r) != null) ? cumulativeReturn(days.map(changeOf)).last : null;
  return [
    for (final MapEntry(key: start, value: days) in groups.entries)
      PeriodPerformance(
        start: start,
        endValue: days.last.portfolioValue,
        pnl: Money.idr(days.fold(0, (sum, r) => sum + r.pnl.amount)),
        returnPercent: cumulativeReturn(days.map((r) => r.pnlPercent)).last,
        ihsgReturn: benchmark(days, (r) => r.ihsgChange),
        sp500Return: benchmark(days, (r) => r.sp500Change),
        btcReturn: benchmark(days, (r) => r.btcChange),
      ),
  ];
}

/// Total untung satu mata uang sejak pembelian: posisi yang masih dipegang + yang sudah dijual + dividen.
class TotalReturn extends Equatable {
  const TotalReturn({
    required this.currency,
    required this.unrealized,
    required this.realized,
    required this.dividends,
    required this.percent,
  });

  final Currency currency;
  final Money unrealized;
  final Money realized;
  final Money dividends;

  /// Terhadap seluruh modal yang pernah dipakai (posisi sekarang + yang sudah dijual). `null` bila modal nol.
  final double? percent;

  Money get total => Money(unrealized.amount + realized.amount + dividends.amount, currency);

  @override
  List<Object?> get props => [currency, unrealized, realized, dividends, percent];
}

/// Per mata uang, tidak dijumlah, jadi tidak perlu kurs historis.
/// Sengaja bukan dari PnL harian: PnL itu sudah memuat kenaikan saham selama dipegang, sehingga menambahkan
/// realized PnL akan menghitungnya dua kali. Posisi tanpa harga terbaru tidak ikut (lihat [Portfolio.unpriced]).
List<TotalReturn> totalReturns(Portfolio portfolio, List<SaleRecord> sales, List<Dividend> dividends, DateTime now) {
  return [for (final c in Currency.values) ?_totalReturnIn(c, portfolio, sales, dividends, now)];
}

TotalReturn? _totalReturnIn(
  Currency c,
  Portfolio portfolio,
  List<SaleRecord> sales,
  List<Dividend> dividends,
  DateTime now,
) {
  final held = portfolio.pricedTotals(c);
  final sold = sales.where((s) => s.currency == c).toList();
  final paid = dividends.where((d) => d.isPaid(now) && d.received?.currency == c).toList();
  if (held == null && sold.isEmpty && paid.isEmpty) return null;

  final unrealized = held?.pnl.amount ?? 0;
  final realized = sold.fold(0.0, (sum, s) => sum + s.realizedPnl.amount);
  final received = paid.fold(0.0, (sum, d) => sum + d.received!.amount);
  final heldCost = held == null ? 0.0 : held.value.amount - held.pnl.amount;
  final soldCost = sold.fold(0.0, (sum, s) => sum + s.proceeds.amount - s.realizedPnl.amount);
  final capital = heldCost + soldCost;
  return TotalReturn(
    currency: c,
    unrealized: Money(unrealized, c),
    realized: Money(realized, c),
    dividends: Money(received, c),
    percent: capital == 0 ? null : (unrealized + realized + received) / capital * 100,
  );
}

/// Ringkasan seluruh riwayat harian. Puncak & drawdown dari return majemuk (TWR), bukan nilai rupiah:
/// top up atau menjual saham mengubah nilai porto, tapi bukan kinerja.
class PerformanceStats extends Equatable {
  const PerformanceStats({
    required this.streakDays,
    required this.streakIsProfit,
    required this.profitDays,
    required this.lossDays,
    required this.peakDate,
    required this.fromPeakPercent,
    required this.maxDrawdownPercent,
    required this.troughDate,
  });

  /// Hari untung/rugi berturut-turut sampai catatan terakhir. Hari datar dilewati, tidak memutus streak.
  final int streakDays;
  final bool streakIsProfit;
  final int profitDays;
  final int lossDays;
  final DateTime peakDate;

  /// 0 = sedang di puncak, negatif = di bawah puncak.
  final double fromPeakPercent;

  /// Penurunan terdalam dari puncak ke lembah; 0 = belum pernah turun.
  final double maxDrawdownPercent;

  /// `null` bila belum pernah turun dari puncak.
  final DateTime? troughDate;

  int get movedDays => profitDays + lossDays;

  /// Persen dari hari yang bergerak; hari datar (bursa tutup) tidak ikut. `null` bila belum ada yang bergerak.
  double? get winRatePercent => movedDays == 0 ? null : profitDays / movedDays * 100;

  @override
  List<Object?> get props => [
    streakDays,
    streakIsProfit,
    profitDays,
    lossDays,
    peakDate,
    fromPeakPercent,
    maxDrawdownPercent,
    troughDate,
  ];
}

/// [rows] urut tanggal naik dan tidak boleh kosong.
PerformanceStats performanceStats(List<DailyPerformance> rows) {
  var index = 1.0;
  var peak = 1.0;
  var peakDate = rows.first.date;
  var maxDrawdown = 0.0;
  DateTime? troughDate;
  for (final r in rows) {
    index *= 1 + r.pnlPercent / 100;
    if (index > peak) {
      peak = index;
      peakDate = r.date;
    }
    final drawdown = (index / peak - 1) * 100;
    if (drawdown < maxDrawdown) {
      maxDrawdown = drawdown;
      troughDate = r.date;
    }
  }

  final moved = rows.reversed.where((r) => r.pnl.amount != 0);
  final streakIsProfit = moved.isNotEmpty && moved.first.pnl.amount > 0;
  return PerformanceStats(
    streakDays: moved.takeWhile((r) => (r.pnl.amount > 0) == streakIsProfit).length,
    streakIsProfit: streakIsProfit,
    profitDays: rows.where((r) => r.pnl.amount > 0).length,
    lossDays: rows.where((r) => r.pnl.amount < 0).length,
    peakDate: peakDate,
    fromPeakPercent: (index / peak - 1) * 100,
    maxDrawdownPercent: maxDrawdown,
    troughDate: troughDate,
  );
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
