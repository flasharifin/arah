import 'package:arah/core/domain/money.dart';
import 'package:equatable/equatable.dart';

class BriefingPreview extends Equatable {
  const BriefingPreview({required this.date, required this.summary, this.full = ''});

  /// Tanggal sebenarnya; briefing terakhir belum tentu hari ini.
  final DateTime date;

  /// Satu paragraf ringkas (baris digabung " · ") untuk kartu Beranda.
  final String summary;

  /// Isi lengkap per baris (tanpa judul) untuk "Baca briefing lengkap"; kosong = pakai [summary].
  final String full;

  String get fullText => full.isEmpty ? summary : full;

  @override
  List<Object?> get props => [date, summary, full];
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
    this.dailyChange,
    this.dailyChangePercent,
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

  /// Perubahan nilai portofolio hari ini (harga terakhir vs penutupan sebelumnya), rupiah.
  final Money? dailyChange;
  final double? dailyChangePercent;

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
    dailyChange,
    dailyChangePercent,
  ];
}
