import 'package:arah/core/domain/money.dart';
import 'package:equatable/equatable.dart';

enum Exchange {
  idx('IDX', 'IDX'),
  us('US', 'US'),
  crypto('CRYPTO', 'Crypto');

  const Exchange(this.code, this.label);

  final String code;
  final String label;

  static Exchange fromCode(String code) => values.firstWhere((e) => e.code == code, orElse: () => Exchange.idx);

  /// IDX dicatat dalam lot (100 lembar), US/Crypto dalam unit.
  String get quantityLabel => this == Exchange.idx ? 'lot' : 'unit';
  int get unitsPerQuantity => this == Exchange.idx ? 100 : 1;
}

/// Satu posisi kepemilikan. Harga terakhir bisa tidak tersedia (`null`), bukan nol.
class Position extends Equatable {
  const Position({
    required this.id,
    required this.symbol,
    required this.exchange,
    required this.quantity,
    required this.avgPrice,
    this.broker = '',
    this.sector,
    this.lastPrice,
  });

  final String id;
  final String symbol;
  final Exchange exchange;

  /// Lot untuk IDX, unit untuk US/Crypto.
  final double quantity;
  final Money avgPrice;
  final String broker;
  final String? sector;
  final Money? lastPrice;

  Currency get currency => avgPrice.currency;
  double get units => quantity * exchange.unitsPerQuantity;
  Money get costBasis => Money(units * avgPrice.amount, currency);
  Money? get marketValue => lastPrice == null ? null : Money(units * lastPrice!.amount, currency);
  Money? get unrealizedPnl => marketValue == null ? null : Money(marketValue!.amount - costBasis.amount, currency);
  double? get unrealizedPercent =>
      unrealizedPnl == null || costBasis.amount == 0 ? null : unrealizedPnl!.amount / costBasis.amount * 100;

  Position copyWith({Money? lastPrice}) => Position(
    id: id,
    symbol: symbol,
    exchange: exchange,
    quantity: quantity,
    avgPrice: avgPrice,
    broker: broker,
    sector: sector,
    lastPrice: lastPrice ?? this.lastPrice,
  );

  @override
  List<Object?> get props => [id, symbol, exchange, quantity, avgPrice, broker, sector, lastPrice];
}
