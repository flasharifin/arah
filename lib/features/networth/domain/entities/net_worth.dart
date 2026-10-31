import 'package:arah/core/domain/money.dart';
import 'package:equatable/equatable.dart';

enum WealthCategory {
  portfolio('Portofolio'),
  cash('Kas'),
  mutualFund('Reksa dana'),
  property('Properti'),
  gold('Emas'),
  defi('DeFi'),
  debt('Utang'),
  other('Lainnya');

  const WealthCategory(this.label);
  final String label;
}

enum WealthKind { asset, liability }

/// Kategori backend (`AssetCategory`) yang ditawarkan form; sama dengan form web.
/// stock/crypto sengaja tidak ditawarkan: saham & kripto dicatat di Portofolio.
const assetCategories = {
  'cash': 'Kas & tabungan',
  'mutual_fund': 'Reksa dana',
  'property': 'Properti',
  'defi': 'DeFi / Web3',
  'gold': 'Emas',
  'other': 'Lainnya',
};
const liabilityCategories = {
  'mortgage': 'KPR',
  'personal_loan': 'KTA / pinjaman pribadi',
  'credit_card': 'Kartu kredit',
  'vehicle_loan': 'Kredit kendaraan',
  'other': 'Lainnya',
};

/// Mata uang aset manual. GOLD dicatat dalam gram dan dikonversi server ke rupiah.
const entryCurrencies = {'IDR': 'Rupiah', 'USD': 'Dolar AS', 'GOLD': 'Emas (gram)'};

/// Aset/utang manual seperti tersimpan di server (nilai mata uang asal) — isi form ubah,
/// dikirim apa adanya ke `/api/networth/assets` atau `/liabilities`.
class ManualEntry extends Equatable {
  const ManualEntry({
    required this.kind,
    required this.name,
    required this.category,
    required this.amount,
    this.currency = 'IDR',
  });

  final WealthKind kind;
  final String name;

  /// Kode kategori backend, lihat [assetCategories] / [liabilityCategories].
  final String category;

  /// Rupiah, dolar AS, atau gram emas sesuai [currency].
  final double amount;

  /// Kunci [entryCurrencies]; utang selalu IDR.
  final String currency;

  @override
  List<Object?> get props => [kind, name, category, amount, currency];
}

class WealthItem extends Equatable {
  const WealthItem({
    required this.id,
    required this.name,
    required this.category,
    required this.value,
    this.isAutomatic = false,
    this.entry,
  });

  final String id;
  final String name;
  final WealthCategory category;
  final Money value;

  /// Aset otomatis dari portofolio; tidak bisa diedit manual agar tidak dihitung ganda.
  final bool isAutomatic;

  /// Nilai asli untuk diubah; `null` untuk item otomatis.
  final ManualEntry? entry;

  @override
  List<Object?> get props => [id, name, category, value, isAutomatic, entry];
}

/// Catatan kekayaan bersih pada satu waktu, total dihitung server dalam rupiah.
class NetWorthSnapshot extends Equatable {
  const NetWorthSnapshot({
    required this.id,
    required this.date,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netValue,
  });

  final String id;
  final DateTime date;
  final Money totalAssets;
  final Money totalLiabilities;
  final Money netValue;

  @override
  List<Object?> get props => [id, date, totalAssets, totalLiabilities, netValue];
}

class WealthGoal extends Equatable {
  const WealthGoal({
    required this.name,
    required this.target,
    this.deadline,
    this.monthlyContribution,
    this.expectedReturnPercent,
  });

  final String name;
  final Money target;
  final DateTime? deadline;
  final Money? monthlyContribution;
  final double? expectedReturnPercent;

  @override
  List<Object?> get props => [name, target, deadline, monthlyContribution, expectedReturnPercent];
}

/// Nilai aset & utang dalam rupiah setelah dikonversi server (`valueIDR` di `/api/summary`),
/// jadi total di sini = penjumlahan item IDR, sama dengan `totalAssetsAll` server.
class NetWorth extends Equatable {
  const NetWorth({required this.assets, required this.liabilities, this.goal, this.asOf, this.snapshots = const []});

  final List<WealthItem> assets;
  final List<WealthItem> liabilities;
  final WealthGoal? goal;
  final DateTime? asOf;

  /// Terbaru dulu.
  final List<NetWorthSnapshot> snapshots;

  Money get totalAssets => Money.idr(assets.fold(0, (sum, i) => sum + i.value.amount));
  Money get totalLiabilities => Money.idr(liabilities.fold(0, (sum, i) => sum + i.value.amount));
  Money get netWorth => Money.idr(totalAssets.amount - totalLiabilities.amount);

  @override
  List<Object?> get props => [assets, liabilities, goal, asOf, snapshots];
}
