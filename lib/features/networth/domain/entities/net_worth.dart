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

class WealthItem extends Equatable {
  const WealthItem({
    required this.id,
    required this.name,
    required this.category,
    required this.value,
    this.isAutomatic = false,
  });

  final String id;
  final String name;
  final WealthCategory category;
  final Money value;

  /// Aset otomatis dari portofolio; tidak bisa diedit manual agar tidak dihitung ganda.
  final bool isAutomatic;

  @override
  List<Object?> get props => [id, name, category, value, isAutomatic];
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

/// Nilai aset & utang dalam rupiah setelah dikonversi server.
// shortcut: total dihitung di client dengan asumsi semua item sudah IDR; pindahkan ke server bila ada item non-IDR.
class NetWorth extends Equatable {
  const NetWorth({required this.assets, required this.liabilities, this.goal, this.asOf});

  final List<WealthItem> assets;
  final List<WealthItem> liabilities;
  final WealthGoal? goal;
  final DateTime? asOf;

  Money get totalAssets => Money.idr(assets.fold(0, (sum, i) => sum + i.value.amount));
  Money get totalLiabilities => Money.idr(liabilities.fold(0, (sum, i) => sum + i.value.amount));
  Money get netWorth => Money.idr(totalAssets.amount - totalLiabilities.amount);

  @override
  List<Object?> get props => [assets, liabilities, goal, asOf];
}
