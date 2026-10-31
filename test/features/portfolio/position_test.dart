import 'package:arah/core/domain/money.dart';
import 'package:arah/features/portfolio/domain/entities/portfolio.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bbca = Position(
    id: 'bbca',
    symbol: 'BBCA',
    exchange: Exchange.idx,
    quantity: 100,
    avgPrice: Money.idr(9000),
    lastPrice: Money.idr(9500),
  );

  test('fixture S04: 100 lot BBCA avg 9.000, harga 9.500', () {
    expect(bbca.units, 10000);
    expect(bbca.costBasis, const Money.idr(90000000));
    expect(bbca.marketValue, const Money.idr(95000000));
    expect(bbca.unrealizedPnl, const Money.idr(5000000));
    expect(bbca.unrealizedPercent, closeTo(5.56, 0.01));
  });

  test('US memakai unit, bukan lot', () {
    const aapl = Position(
      id: 'a',
      symbol: 'AAPL',
      exchange: Exchange.us,
      quantity: 2,
      avgPrice: Money.usd(100),
      lastPrice: Money.usd(110),
    );
    expect(aapl.marketValue, const Money.usd(220));
  });

  test('harga hilang membuat nilai null, bukan nol', () {
    const noPrice = Position(id: 'x', symbol: 'X', exchange: Exchange.idx, quantity: 1, avgPrice: Money.idr(1));
    expect(noPrice.marketValue, isNull);
    expect(const Portfolio(positions: [bbca, noPrice]).marketValue(Currency.idr), isNull);
  });

  test('total tidak mencampur mata uang', () {
    const aapl = Position(
      id: 'a',
      symbol: 'AAPL',
      exchange: Exchange.us,
      quantity: 1,
      avgPrice: Money.usd(100),
      lastPrice: Money.usd(100),
    );
    const portfolio = Portfolio(positions: [bbca, aapl]);
    expect(portfolio.marketValue(Currency.idr), const Money.idr(95000000));
    expect(portfolio.marketValue(Currency.usd), const Money.usd(100));
  });
}
