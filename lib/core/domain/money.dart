import 'package:equatable/equatable.dart';

enum Currency { idr, usd }

/// Nominal dalam mata uang asal. Harga aset tidak dikonversi diam-diam.
// shortcut: double cukup untuk tampilan karena server menghitung dengan decimal; ganti ke decimal jika client mulai menghitung transaksi.
class Money extends Equatable {
  const Money(this.amount, this.currency);
  const Money.idr(this.amount) : currency = Currency.idr;
  const Money.usd(this.amount) : currency = Currency.usd;

  final double amount;
  final Currency currency;

  bool get isNegative => amount < 0;

  @override
  List<Object?> get props => [amount, currency];
}
