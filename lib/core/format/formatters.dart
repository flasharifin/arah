import 'package:arah/core/domain/money.dart';
import 'package:intl/intl.dart';

/// Format angka sesuai locale Indonesia (doc/designapp/03-design-system.md).
/// Nilai `null` berarti data tidak tersedia dan tampil `—`, bukan nol.
abstract final class Fmt {
  static const missing = '—';
  static const hidden = '••••••';

  static final _idr = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  static final _usd = NumberFormat.currency(locale: 'id', symbol: r'US$ ', decimalDigits: 2);
  static final _number = NumberFormat.decimalPattern('id');
  static final _decimal2 = NumberFormat('#,##0.00', 'id');

  /// `Rp 128.450.000`, `US$ 185,50`. [signed] menambah `+`/`−` untuk PnL.
  static String money(Money? value, {bool signed = false}) {
    if (value == null) return missing;
    final formatter = value.currency == Currency.idr ? _idr : _usd;
    final text = formatter.format(value.amount.abs());
    return '${_sign(value.amount, signed)}$text';
  }

  /// `Rp 98,45 jt`, `Rp 1 M` untuk ringkasan di kartu kecil.
  static String moneyCompact(Money? value) {
    if (value == null) return missing;
    if (value.currency != Currency.idr) return money(value);
    final abs = value.amount.abs();
    final sign = value.isNegative ? '−' : '';
    String scaled(double divisor, String unit) {
      final v = abs / divisor;
      final text = v == v.roundToDouble() ? _number.format(v) : _decimal2.format(v);
      return '${sign}Rp $text $unit';
    }

    if (abs >= 1e12) return scaled(1e12, 'T');
    if (abs >= 1e9) return scaled(1e9, 'M');
    if (abs >= 1e6) return scaled(1e6, 'jt');
    return money(value);
  }

  /// `+2,40%`. Input dalam persen (2.4 = 2,40%).
  static String percent(double? value, {bool signed = true}) {
    if (value == null) return missing;
    return '${_sign(value, signed)}${_decimal2.format(value.abs())}%';
  }

  static String number(num? value) => value == null ? missing : _number.format(value);

  /// `28 Okt 2026`.
  static String date(DateTime? value) =>
      value == null ? missing : DateFormat('d MMM yyyy', 'id').format(value.toLocal());

  /// `28 Okt, 09.30 WIB` — waktu selalu tampil dengan zona.
  static String dateTime(DateTime? value) {
    if (value == null) return missing;
    final local = value.toLocal();
    return '${DateFormat('d MMM, HH.mm', 'id').format(local)} ${local.timeZoneName}';
  }

  static String _sign(double value, bool signed) {
    if (value < 0) return '−';
    if (signed && value > 0) return '+';
    return '';
  }
}
