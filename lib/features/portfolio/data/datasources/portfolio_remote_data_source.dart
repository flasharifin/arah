import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/portfolio/data/models/position_model.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/portfolio/domain/entities/purchase.dart';

abstract interface class PortfolioRemoteDataSource {
  Future<Portfolio> fetchPortfolio();
  Future<void> recordPurchase(PositionPurchase purchase);
}

/// Posisi + harga dari `/api/summary`: satu request, sumber yang sama dengan Beranda & dashboard web.
class PortfolioApiDataSource implements PortfolioRemoteDataSource {
  const PortfolioApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<Portfolio> fetchPortfolio() async {
    final summary = await _api.get('/api/summary') as Map<String, dynamic>;
    final raw = (summary['positions'] as List<dynamic>).cast<Map<String, dynamic>>();
    final fetchedAt = raw.map((p) => p['priceFetchedAt']).whereType<String>().map(DateTime.parse);
    return Portfolio(
      positions: raw.map(PositionModel.fromJson).toList(),
      // Harga paling lama = batas kesegaran seluruh daftar (harga bisa dari cache server).
      priceAsOf: fetchedAt.isEmpty ? null : fetchedAt.reduce((a, b) => a.isBefore(b) ? a : b),
      usdToIdr: ((summary['asOf'] as Map<String, dynamic>?)?['usdToIdr'] as num?)?.toDouble(),
    );
  }

  /// `POST /api/portfolio` = tambah posisi (kode + broker sama → lot dijumlah, rata-rata dihitung ulang).
  @override
  Future<void> recordPurchase(PositionPurchase p) => _api.post(
    '/api/portfolio',
    body: {
      'stockCode': p.symbol.trim().toUpperCase(),
      'exchange': p.exchange.code,
      'currency': p.exchange == Exchange.idx ? 'IDR' : 'USD',
      'platform': p.broker.trim(),
      'lot': p.quantity,
      'avgPrice': p.price,
      'purchaseDate': p.date.toIso8601String(),
      'sector': p.sector,
      'note': p.note,
      'requestId': p.requestId,
    },
  );
}

/// Data ilustrasi dari galeri desain (S03/S04), disimpan di memori supaya pencatatan pembelian bisa dicoba.
class PortfolioFixtureDataSource implements PortfolioRemoteDataSource {
  final _seen = <String>{};

  @override
  Future<Portfolio> fetchPortfolio() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return Portfolio(priceAsOf: DateTime.now(), positions: List.of(_positions), usdToIdr: 16000);
  }

  /// Sama seperti server: kode + broker yang sudah ada → lot dijumlah, rata-rata tertimbang.
  @override
  Future<void> recordPurchase(PositionPurchase p) async {
    if (!_seen.add(p.requestId)) return;
    final symbol = p.symbol.trim().toUpperCase();
    final i = _positions.indexWhere((x) => x.symbol == symbol && x.broker == p.broker.trim());
    final currency = p.exchange == Exchange.idx ? Currency.idr : Currency.usd;
    if (i < 0) {
      _positions.add(
        Position(
          id: '${symbol.toLowerCase()}-${_positions.length}',
          symbol: symbol,
          exchange: p.exchange,
          broker: p.broker.trim(),
          sector: p.sector,
          quantity: p.quantity,
          avgPrice: Money(p.price, currency),
        ),
      );
      return;
    }
    final old = _positions[i];
    final quantity = old.quantity + p.quantity;
    _positions[i] = Position(
      id: old.id,
      symbol: old.symbol,
      exchange: old.exchange,
      broker: old.broker,
      sector: old.sector,
      quantity: quantity,
      avgPrice: Money((old.quantity * old.avgPrice.amount + p.quantity * p.price) / quantity, old.currency),
      lastPrice: old.lastPrice,
    );
  }

  final _positions = <Position>[
    const Position(
      id: 'bbca',
      symbol: 'BBCA',
      exchange: Exchange.idx,
      broker: 'Stockbit',
      sector: 'Keuangan',
      quantity: 100,
      avgPrice: Money.idr(9000),
      lastPrice: Money.idr(9500),
    ),
    const Position(
      id: 'tlkm',
      symbol: 'TLKM',
      exchange: Exchange.idx,
      broker: 'Ajaib',
      sector: 'Telekomunikasi',
      quantity: 20,
      avgPrice: Money.idr(3200),
      lastPrice: Money.idr(2950),
    ),
    const Position(
      id: 'aapl',
      symbol: 'AAPL',
      exchange: Exchange.us,
      broker: 'Gotrade',
      quantity: 4.5,
      avgPrice: Money.usd(172.4),
      lastPrice: Money.usd(185.5),
    ),
    const Position(
      id: 'btc',
      symbol: 'BTC',
      exchange: Exchange.crypto,
      broker: 'Indodax',
      quantity: 0.012,
      avgPrice: Money.usd(61000),
    ),
  ];
}
