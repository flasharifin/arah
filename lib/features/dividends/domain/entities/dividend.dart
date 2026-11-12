import 'package:arah/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// Satu jadwal/penerimaan dividen. Tanggal kosong berarti belum ditentukan, bukan hari ini.
class Dividend extends Equatable {
  const Dividend({
    required this.id,
    required this.portfolioId,
    required this.symbol,
    required this.dps,
    this.taxPercent = 10,
    this.cumDate,
    this.exDate,
    this.paymentDate,
    this.received,
    this.note,
  });

  final String id;
  final String portfolioId;
  final String symbol;

  /// Dividen per saham, dalam mata uang saham.
  final double dps;
  final double taxPercent;
  final DateTime? cumDate;
  final DateTime? exDate;
  final DateTime? paymentDate;

  /// Jumlah bersih yang diterima (dihitung server dari lot × DPS − pajak), dalam mata uang saham.
  final Money? received;
  final String? note;

  /// Sudah dibayar = tanggal bayar sudah lewat.
  bool isPaid(DateTime now) => paymentDate != null && !paymentDate!.isAfter(now);

  @override
  List<Object?> get props => [id, portfolioId, symbol, dps, taxPercent, cumDate, exDate, paymentDate, received, note];
}

/// Total per mata uang dan gabungannya dalam rupiah. [combinedIdr] null bila ada dolar tapi kurs belum tersedia,
/// supaya dolar tidak terhitung dengan kurs tebakan.
({double idr, double usd, double? combinedIdr}) dividendTotals(Iterable<Dividend> items, double? usdToIdr) {
  double sumIn(Currency c) =>
      items.where((d) => d.received?.currency == c).fold(0, (sum, d) => sum + d.received!.amount);
  final idr = sumIn(Currency.idr);
  final usd = sumIn(Currency.usd);
  return (idr: idr, usd: usd, combinedIdr: usd == 0 ? idr : (usdToIdr == null ? null : idr + usd * usdToIdr));
}

/// Isian form tambah/ubah. Posisi hanya dipilih saat tambah.
class DividendDraft {
  const DividendDraft({
    required this.portfolioId,
    required this.symbol,
    required this.dps,
    required this.taxPercent,
    this.cumDate,
    this.exDate,
    this.paymentDate,
    this.note,
  });

  final String portfolioId;
  final String symbol;
  final double dps;
  final double taxPercent;
  final DateTime? cumDate;
  final DateTime? exDate;
  final DateTime? paymentDate;
  final String? note;
}
