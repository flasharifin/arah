import 'package:arah/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// Sumber dana sebuah transaksi (beli/jual/DCA/dividen): aset kas di Kekayaan yang saldonya ikut berubah.
/// [amount] = jumlah terpotong/diterima dalam mata uang aset bila beda dari hitungan (biaya, kurs broker).
typedef CashSource = ({String assetId, double? amount});

/// Isian body request untuk [CashSource]; kosong = kas tidak disentuh.
Map<String, Object> cashSourceBody(CashSource? s) =>
    s == null ? {} : {'cashAssetId': s.assetId, 'cashAmount': ?s.amount};

enum CashMovementKind {
  purchase('Beli'),
  sale('Jual'),
  dca('DCA'),
  dividend('Dividen'),
  income('Gaji'),
  manual('Manual'),
  opening('Saldo awal');

  const CashMovementKind(this.label);
  final String label;

  static CashMovementKind parse(String v) =>
      values.firstWhere((k) => k.name == v, orElse: () => CashMovementKind.manual);
}

/// Satu mutasi kas (`CashMovement` server). [amount] bertanda, mata uang aset.
class CashMovement extends Equatable {
  const CashMovement({
    required this.id,
    required this.assetId,
    required this.assetName,
    required this.kind,
    required this.title,
    required this.amount,
    required this.amountIdr,
    required this.balanceAfter,
    required this.date,
    this.reversal = false,
    this.reversed = false,
  });

  final String id;
  final String assetId;
  final String assetName;
  final CashMovementKind kind;
  final String title;
  final Money amount;
  final double amountIdr;
  final Money balanceAfter;
  final DateTime date;

  /// Mutasi ini pembatalan mutasi lain.
  final bool reversal;

  /// Mutasi ini sudah dibatalkan.
  final bool reversed;

  bool get canReverse => !reversal && !reversed && kind != CashMovementKind.opening;

  @override
  List<Object?> get props => [id, kind, title, amount, balanceAfter, date, reversal, reversed];
}

/// Angka satu bulan (rupiah). Pengeluaran adalah perkiraan: pemasukan − diinvestasikan − kenaikan kas.
class CashflowMonth extends Equatable {
  const CashflowMonth({
    required this.month,
    required this.salary,
    required this.dividends,
    required this.otherIncome,
    required this.totalIncome,
    required this.invested,
    required this.cashDelta,
    required this.expense,
    required this.saved,
    required this.hasData,
    this.savingsRatePercent,
  });

  /// Awal bulan (lokal).
  final DateTime month;
  final double salary;
  final double dividends;

  /// Penyesuaian manual bersih yang positif (mis. bonus yang tidak tercatat).
  final double otherIncome;
  final double totalIncome;

  /// Beli + DCA − jual yang lewat sumber dana.
  final double invested;
  final double cashDelta;
  final double expense;

  /// Ditabung & diinvestasikan = [totalIncome] − [expense].
  final double saved;
  final bool hasData;
  final double? savingsRatePercent;

  @override
  List<Object?> get props => [month, totalIncome, invested, cashDelta, expense, saved, hasData];
}

/// Aset kas dengan saldo akhir bulan (setara rupiah) untuk grafik.
class CashAssetBalance extends Equatable {
  const CashAssetBalance({
    required this.id,
    required this.name,
    required this.value,
    required this.valueIdr,
    required this.balances,
  });
  final String id;
  final String name;

  /// Saldo sekarang dalam mata uang aset.
  final Money value;
  final double valueIdr;

  /// Urut bulan naik; `null` = bulan belum terjadi.
  final List<({DateTime month, double? valueIdr})> balances;

  @override
  List<Object?> get props => [id, name, value, balances];
}

class EmergencyFund extends Equatable {
  const EmergencyFund({
    required this.targetMonths,
    required this.totalIdr,
    required this.basisMonths,
    this.avgExpense,
    this.coveredMonths,
    this.shortfall,
    this.monthsToFull,
  });

  final int targetMonths;

  /// Semua aset kas, setara rupiah.
  final double totalIdr;

  /// Bulan yang dipakai untuk rata-rata pengeluaran (0 = belum ada data).
  final int basisMonths;
  final double? avgExpense;
  final double? coveredMonths;
  final double? shortfall;
  final int? monthsToFull;

  @override
  List<Object?> get props => [targetMonths, totalIdr, avgExpense, coveredMonths, shortfall, monthsToFull];
}

class CashflowSettings extends Equatable {
  const CashflowSettings({this.monthlyIncome, this.incomeDay, this.incomeAssetId, this.emergencyMonths = 6});

  /// Gaji tetap per bulan (rupiah); `null` = belum diatur.
  final double? monthlyIncome;

  /// Tanggal gajian 1–31 (31 = hari terakhir di bulan pendek).
  final int? incomeDay;
  final String? incomeAssetId;
  final int emergencyMonths;

  bool get hasSalary => monthlyIncome != null && incomeDay != null && incomeAssetId != null;

  @override
  List<Object?> get props => [monthlyIncome, incomeDay, incomeAssetId, emergencyMonths];
}

/// Tab Arus kas untuk satu bulan.
class CashflowOverview extends Equatable {
  const CashflowOverview({
    required this.month,
    required this.summary,
    required this.series,
    required this.assets,
    required this.emergency,
    required this.recent,
    required this.settings,
    this.plan,
    this.dataSince,
  });

  final DateTime month;
  final CashflowMonth summary;

  /// 12 bulan, urut naik, berakhir di [month].
  final List<CashflowMonth> series;
  final List<CashAssetBalance> assets;
  final EmergencyFund emergency;
  final List<CashMovement> recent;
  final CashflowSettings settings;

  /// Setoran/bulan di Target; `null` = belum diatur.
  final double? plan;

  /// Mutasi pertama; `null` = belum ada data sama sekali.
  final DateTime? dataSince;

  double get totalCashIdr => assets.fold(0, (s, a) => s + a.valueIdr);

  @override
  List<Object?> get props => [month, summary, series, assets, emergency, recent, settings, plan, dataSince];
}

/// Layar Mutasi kas: saldo harian + daftar, untuk satu aset ([asset] != null) atau semua (rupiah).
class CashMovementPage extends Equatable {
  const CashMovementPage({
    required this.currency,
    required this.days,
    required this.balance,
    required this.totalIn,
    required this.totalOut,
    required this.items,
    this.assetName,
    this.truncated = false,
  });

  final Currency currency;
  final int days;
  final List<({DateTime date, double value})> balance;
  final double totalIn;
  final double totalOut;
  final List<CashMovement> items;
  final String? assetName;
  final bool truncated;

  @override
  List<Object?> get props => [currency, days, balance, totalIn, totalOut, items, assetName];
}
