import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/portfolio/data/models/position_model.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';

abstract interface class PortfolioRemoteDataSource {
  Future<Portfolio> fetchPortfolio();
}

/// Menggabungkan holding (`/api/portfolio`) dengan harga (`/api/market`).
class PortfolioApiDataSource implements PortfolioRemoteDataSource {
  const PortfolioApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<Portfolio> fetchPortfolio() async {
    final raw = await _api.get('/api/portfolio') as List<dynamic>;
    final positions = raw.cast<Map<String, dynamic>>().map(PositionModel.fromJson).toList();
    if (positions.isEmpty) return const Portfolio(positions: []);

    final keys = positions.map((p) => '${p.symbol}:${p.exchange.code}').toSet().join(',');
    final prices = await _api.get('/api/market', query: {'assets': keys}) as Map<String, dynamic>;
    return Portfolio(
      priceAsOf: DateTime.now(),
      positions: [
        for (final p in positions)
          switch (prices['${p.symbol}:${p.exchange.code}']) {
            {'price': final num price} => p.copyWith(lastPrice: Money(price.toDouble(), p.currency)),
            _ => p,
          },
      ],
    );
  }
}

/// Data ilustrasi dari galeri desain (S03/S04).
class PortfolioFixtureDataSource implements PortfolioRemoteDataSource {
  @override
  Future<Portfolio> fetchPortfolio() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return Portfolio(
      priceAsOf: DateTime.now(),
      positions: const [
        Position(
          id: 'bbca',
          symbol: 'BBCA',
          exchange: Exchange.idx,
          broker: 'Stockbit',
          sector: 'Keuangan',
          quantity: 100,
          avgPrice: Money.idr(9000),
          lastPrice: Money.idr(9500),
        ),
        Position(
          id: 'tlkm',
          symbol: 'TLKM',
          exchange: Exchange.idx,
          broker: 'Ajaib',
          sector: 'Telekomunikasi',
          quantity: 20,
          avgPrice: Money.idr(3200),
          lastPrice: Money.idr(2950),
        ),
        Position(
          id: 'aapl',
          symbol: 'AAPL',
          exchange: Exchange.us,
          broker: 'Gotrade',
          quantity: 4.5,
          avgPrice: Money.usd(172.4),
          lastPrice: Money.usd(185.5),
        ),
        Position(
          id: 'btc',
          symbol: 'BTC',
          exchange: Exchange.crypto,
          broker: 'Indodax',
          quantity: 0.012,
          avgPrice: Money.usd(61000),
        ),
      ],
    );
  }
}
