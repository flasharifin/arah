import 'package:arah/features/portfolio/domain/entities/position.dart';

/// Pencatatan pembelian yang SUDAH dilakukan di broker (S17), bukan order ke bursa.
/// Kode + broker yang sudah ada → lot ditambah & harga rata-rata dihitung ulang di server.
class PositionPurchase {
  const PositionPurchase({
    required this.symbol,
    required this.exchange,
    required this.broker,
    required this.quantity,
    required this.price,
    required this.date,
    required this.requestId,
    this.sector,
    this.note,
  });

  final String symbol;
  final Exchange exchange;
  final String broker;

  /// Lot untuk IDX, unit untuk US/Crypto.
  final double quantity;
  final double price;
  final DateTime date;

  /// Dibuat sekali per form: menekan Simpan lagi setelah gagal jaringan tidak menambah lot dua kali.
  final String requestId;
  final String? sector;
  final String? note;

  double get total => quantity * exchange.unitsPerQuantity * price;
}
