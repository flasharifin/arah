import 'package:arah/core/domain/money.dart';
import 'package:equatable/equatable.dart';

class BriefingPreview extends Equatable {
  const BriefingPreview({required this.date, required this.summary});

  /// Tanggal sebenarnya; briefing terakhir belum tentu hari ini.
  final DateTime date;
  final String summary;

  @override
  List<Object?> get props => [date, summary];
}

class DashboardSummary extends Equatable {
  const DashboardSummary({
    required this.netWorth,
    required this.totalAssets,
    required this.totalLiabilities,
    this.portfolioValue,
    this.healthScore,
    this.goalTarget,
    this.briefing,
    this.asOf,
  });

  final Money netWorth;
  final Money totalAssets;
  final Money totalLiabilities;
  final Money? portfolioValue;

  /// Skor kesehatan investasi 0–100; `null` jika data belum cukup.
  final int? healthScore;
  final Money? goalTarget;
  final BriefingPreview? briefing;
  final DateTime? asOf;

  @override
  List<Object?> get props => [
    netWorth,
    totalAssets,
    totalLiabilities,
    portfolioValue,
    healthScore,
    goalTarget,
    briefing,
    asOf,
  ];
}
