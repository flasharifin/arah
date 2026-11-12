import 'package:arah/core/domain/money.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';
import 'package:flutter_test/flutter_test.dart';

Dividend _d(String id, Money? received) => Dividend(id: id, portfolioId: 'p', symbol: 'X', dps: 1, received: received);

void main() {
  test('rupiah dan dolar dijumlah terpisah, gabungan memakai kurs', () {
    final t = dividendTotals([
      _d('a', const Money.idr(1000)),
      _d('b', const Money.usd(2.5)),
      _d('c', const Money.idr(500)),
      _d('d', null), // belum ada jumlah diterima
    ], 16000);
    expect(t.idr, 1500);
    expect(t.usd, 2.5);
    expect(t.combinedIdr, 41500);
  });

  test('ada dolar tapi kurs belum ada → gabungan kosong, bukan kurs tebakan', () {
    expect(dividendTotals([_d('a', const Money.usd(1))], null).combinedIdr, isNull);
  });

  test('hanya rupiah: gabungan tetap ada walau kurs belum dimuat', () {
    final t = dividendTotals([_d('a', const Money.idr(700))], null);
    expect((t.idr, t.usd, t.combinedIdr), (700.0, 0.0, 700.0));
    expect(dividendTotals(const [], null).combinedIdr, 0);
  });
}
