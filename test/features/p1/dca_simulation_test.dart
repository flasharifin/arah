import 'package:arah/core/domain/money.dart';
import 'package:arah/features/dca/domain/entities/dca.dart';
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

  test('simulasi DCA: rata-rata tertimbang per lot, modal pakai 100 lembar/lot (IDX)', () {
    final r = simulateDca(bbca, quantity: 10, price: 8000);
    expect(r.newAvgPrice, closeTo(980000 / 110, 1e-9)); // (100×9000 + 10×8000) / 110 = 8909,09
    expect(r.totalQuantity, 110);
    expect(r.additionalCost, 8000000); // 10 lot × 100 × 8000
    expect(r.totalCost, 98000000); // 90 jt + 8 jt
    expect(r.marketGap, closeTo(980000 / 110 - 9500, 1e-9)); // negatif = sudah profit
  });

  test('simulasi DCA: US per unit, tanpa harga pasar → selisih pasar null', () {
    const aapl = Position(id: 'aapl', symbol: 'AAPL', exchange: Exchange.us, quantity: 4, avgPrice: Money.usd(150));
    final r = simulateDca(aapl, quantity: 1, price: 200);
    expect(r.newAvgPrice, 160); // (4×150 + 200) / 5
    expect(r.additionalCost, 200);
    expect(r.marketGap, isNull);
  });
}
