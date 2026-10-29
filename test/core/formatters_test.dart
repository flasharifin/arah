import 'package:arah/core/domain/money.dart';
import 'package:arah/core/format/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  test('format rupiah dan dolar sesuai locale Indonesia', () {
    expect(Fmt.money(const Money.idr(128450000)), 'Rp 128.450.000');
    expect(Fmt.money(const Money.usd(185.5)), r'US$ 185,50');
  });

  test('nilai tidak tersedia tampil —, bukan nol', () {
    expect(Fmt.money(null), '—');
    expect(Fmt.money(const Money.idr(0)), 'Rp 0');
  });

  test('PnL selalu bertanda', () {
    expect(Fmt.money(const Money.idr(5000000), signed: true), '+Rp 5.000.000');
    expect(Fmt.money(const Money.idr(-5000), signed: true), '−Rp 5.000');
    expect(Fmt.percent(2.4), '+2,40%');
    expect(Fmt.percent(-1.2), '−1,20%');
  });

  test('format ringkas', () {
    expect(Fmt.moneyCompact(const Money.idr(98450000)), 'Rp 98,45 jt');
    expect(Fmt.moneyCompact(const Money.idr(1000000000)), 'Rp 1 M');
  });

  test('tanggal pendek', () {
    expect(Fmt.date(DateTime(2026, 10, 28)), '28 Okt 2026');
  });
}
