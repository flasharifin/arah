import 'package:arah/features/cashflow/domain/entities/cashflow.dart';

/// Pencatatan penjualan yang SUDAH dilakukan di broker, bukan order ke bursa.
/// Lot berkurang; harga rata-rata sisa posisi tidak berubah. Realized PnL dihitung server.
class PositionSale {
  const PositionSale({
    required this.positionId,
    required this.quantity,
    required this.price,
    required this.date,
    required this.requestId,
    this.note,
    this.cashSource,
  });

  final String positionId;

  /// Lot untuk IDX, unit untuk US/Crypto.
  final double quantity;
  final double price;
  final DateTime date;

  /// Dibuat sekali per form: menekan Simpan lagi setelah gagal jaringan tidak menjual dua kali.
  final String requestId;
  final String? note;

  /// Aset kas penerima hasil jual; `null` = kas tidak disentuh.
  final CashSource? cashSource;
}
