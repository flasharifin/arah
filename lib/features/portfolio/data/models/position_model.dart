import 'package:arah/core/domain/money.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';

/// Pemetaan posisi dari `/api/summary` (`positions`, sudah berisi `marketPrice`) atau baris
/// Prisma `/api/portfolio`. Decimal Prisma diserialisasi sebagai string, jadi parse keduanya.
class PositionModel extends Position {
  const PositionModel({
    required super.id,
    required super.symbol,
    required super.exchange,
    required super.quantity,
    required super.avgPrice,
    super.broker,
    super.sector,
    super.lastPrice,
  });

  factory PositionModel.fromJson(Map<String, dynamic> json) {
    final currency = json['currency'] == 'USD' ? Currency.usd : Currency.idr;
    return PositionModel(
      id: json['id'] as String,
      symbol: json['stockCode'] as String,
      exchange: Exchange.fromCode(json['exchange'] as String? ?? 'IDX'),
      quantity: _decimal(json['lot']),
      avgPrice: Money(_decimal(json['avgPrice']), currency),
      broker: json['platform'] as String? ?? '',
      sector: json['sector'] as String?,
      // null = harga gagal diambil server, bukan nol
      lastPrice: json['marketPrice'] == null ? null : Money(_decimal(json['marketPrice']), currency),
    );
  }

  static double _decimal(Object? v) => v is num ? v.toDouble() : double.parse(v.toString());
}
