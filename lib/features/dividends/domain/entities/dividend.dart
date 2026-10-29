import 'package:arah/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// Satu jadwal/penerimaan dividen. Tanggal kosong berarti belum ditentukan, bukan hari ini.
class Dividend extends Equatable {
  const Dividend({
    required this.id,
    required this.symbol,
    required this.dps,
    this.exDate,
    this.paymentDate,
    this.received,
  });

  final String id;
  final String symbol;

  /// Dividen per saham, dalam mata uang saham.
  final double dps;
  final DateTime? exDate;
  final DateTime? paymentDate;

  /// Jumlah bersih yang diterima; dashboard menjumlahkannya sebagai rupiah.
  final Money? received;

  /// Sudah dibayar = tanggal bayar sudah lewat.
  bool isPaid(DateTime now) => paymentDate != null && !paymentDate!.isAfter(now);

  @override
  List<Object?> get props => [id, symbol, dps, exDate, paymentDate, received];
}
