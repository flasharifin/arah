import 'package:arah/core/domain/money.dart';
import 'package:arah/features/calculator/domain/entities/calculators.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BEP IDX memasukkan biaya beli & jual, US tanpa biaya', () {
    expect(breakEvenPrice(1000, Exchange.idx), closeTo(1000 * 1.0015 / 0.9975, 1e-9));
    expect(breakEvenPrice(150, Exchange.us), 150);
  });

  test('lot IDX: biaya beli ikut dihitung sehingga sisa tidak minus', () {
    // 1.000.000 / (5.000 × 100) = 2 lot tepat, tapi +biaya 0,15% tidak cukup → 1 lot.
    final r = lotCalc(exchange: Exchange.idx, budget: 1000000, price: 5000)!;
    expect(r.quantity, 1);
    expect(r.units, 100);
    expect(r.left, greaterThanOrEqualTo(0));
    expect(lotCalc(exchange: Exchange.idx, budget: 100000, price: 5000), isNull);
    final us = lotCalc(exchange: Exchange.us, budget: 1000, price: 150, feePercent: 0)!;
    expect(us.quantity, 6.6666);
  });

  test('position sizing: rugi di stop loss ≤ risiko % porto', () {
    final r = positionSizing(
      exchange: Exchange.idx,
      portfolioIdr: 100000000,
      entry: 1000,
      stopLoss: 900,
      riskPercent: 1,
      usdToIdr: 16000,
    )!;
    // risiko maks 1 jt / Rp100 per lembar = 10.000 lembar = 100 lot
    expect(r.quantity, 100);
    expect(r.maxLossIdr, 1000000);
    expect(r.capitalIdr, 10000000);
    expect(
      positionSizing(exchange: Exchange.idx, portfolioIdr: 1, entry: 900, stopLoss: 1000, riskPercent: 1, usdToIdr: 1),
      isNull,
    );
  });

  test('averaging: rata-rata tertimbang & BEP baru', () {
    const p = Position(id: 'x', symbol: 'X', exchange: Exchange.idx, quantity: 10, avgPrice: Money.idr(1000));
    final r = averaging(p, extraQuantity: 10, price: 800);
    expect(r.newAvg, 900);
    expect(r.extraCost, 800000);
  });

  test('FI: target >5 tahun tetap ditemukan (web berhenti di 60 bulan)', () {
    final r = fiCalc(currentIdr: 0, monthlyExpense: 10000000, monthlySaving: 10000000, annualReturnPercent: 10);
    expect(r.fiNumber, 3000000000);
    expect(r.years, isNotNull);
    expect(r.years, greaterThan(5));
    expect(fiCalc(currentIdr: 4e9, monthlyExpense: 10000000, monthlySaving: 0, annualReturnPercent: 10).years, 0);
  });

  test('rebalancing: target harus 100%, aksi = target × (total + dana baru) − nilai', () {
    final values = {Exchange.idx: 80.0, Exchange.us: 20.0, Exchange.crypto: 0.0};
    expect(rebalance(values, {Exchange.idx: 70, Exchange.us: 20, Exchange.crypto: 5}), isNull);
    final rows = rebalance(values, {Exchange.idx: 70, Exchange.us: 20, Exchange.crypto: 10}, newFundsIdr: 100)!;
    expect(rows.map((r) => r.actionIdr), [60, 20, 20]);
    expect(rows.first.actualPercent, 80);
  });
}
