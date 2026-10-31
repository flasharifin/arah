import 'package:arah/core/domain/money.dart';
import 'package:equatable/equatable.dart';

/// Risiko satu posisi (rumus server = halaman web /analisis): histori harga 1 bulan.
class RiskPosition extends Equatable {
  const RiskPosition({
    required this.symbol,
    required this.exchange,
    required this.value,
    required this.weight,
    required this.hasPrice,
    this.volatility,
    this.maxDrawdown,
  });

  final String symbol;

  /// Kode bursa backend: IDX / US / CRYPTO.
  final String exchange;

  /// Nilai pasar dalam rupiah, atau modal bila harga belum tersedia ([hasPrice] false).
  final Money value;
  final double weight;
  final bool hasPrice;

  /// Persen tahunan; `null` = histori belum cukup.
  final double? volatility;
  final double? maxDrawdown;

  String get key => '$symbol:$exchange';

  @override
  List<Object?> get props => [symbol, exchange, value, weight, hasPrice, volatility, maxDrawdown];
}

/// Penurunan per bursa dalam persen (negatif = turun).
typedef Drops = ({double idx, double us, double crypto});

class StressScenario extends Equatable {
  const StressScenario({required this.id, required this.label, required this.description, required this.drops});
  final String id;
  final String label;
  final String description;
  final Drops drops;

  bool get isCustom => id == 'custom';

  @override
  List<Object?> get props => [id, label, description, drops];
}

/// Sharpe & beta level portofolio dari catatan PnL harian (maks 1 tahun); `null` = data < 20 hari.
class PortfolioRisk extends Equatable {
  const PortfolioRisk({
    required this.riskFreePercent,
    required this.days,
    this.sharpe,
    this.betaIhsg,
    this.betaSp500,
    this.betaBtc,
  });
  final double? sharpe;

  /// Asumsi imbal hasil bebas risiko per tahun yang dipakai Sharpe.
  final double riskFreePercent;
  final double? betaIhsg;
  final double? betaSp500;
  final double? betaBtc;
  final int days;

  @override
  List<Object?> get props => [sharpe, riskFreePercent, betaIhsg, betaSp500, betaBtc, days];
}

class RiskAnalysis extends Equatable {
  const RiskAnalysis({
    required this.positions,
    required this.correlations,
    required this.scenarios,
    required this.historyDays,
    this.portfolio,
  });

  /// `null` bila server belum mengirim (versi lama).
  final PortfolioRisk? portfolio;

  final List<RiskPosition> positions;

  /// Kunci `SIMBOL:BURSA`; hanya aset dengan ≥5 hari perdagangan bersama.
  final List<({String a, String b, double? r})> correlations;
  final List<StressScenario> scenarios;

  /// Hari perdagangan bersama untuk korelasi; 0 = belum bisa dihitung.
  final int historyDays;

  RiskPosition? get largest => positions.isEmpty ? null : positions.reduce((a, b) => a.weight >= b.weight ? a : b);

  @override
  List<Object?> get props => [positions, correlations, scenarios, historyDays, portfolio];
}

/// Label tingkat sama dengan web (volLevel / ddLevel).
String volatilityLevel(double? v) => v == null ? '—' : (v < 20 ? 'Rendah' : (v < 50 ? 'Sedang' : 'Tinggi'));
String drawdownLevel(double? d) => d == null ? '—' : (d < 10 ? 'Rendah' : (d < 25 ? 'Sedang' : 'Tinggi'));

/// Stress test: nilai tiap posisi × (1 + penurunan bursanya). Sama dengan StressTestTab web.
({Money before, Money after, List<({RiskPosition position, Money delta})> rows}) stressImpact(
  List<RiskPosition> positions,
  Drops drops,
) {
  var before = 0.0, after = 0.0;
  final rows = <({RiskPosition position, Money delta})>[];
  for (final p in positions) {
    final drop = switch (p.exchange) {
      'US' => drops.us,
      'CRYPTO' => drops.crypto,
      _ => drops.idx,
    };
    final next = p.value.amount * (1 + drop / 100);
    before += p.value.amount;
    after += next;
    rows.add((position: p, delta: Money.idr(next - p.value.amount)));
  }
  return (before: Money.idr(before), after: Money.idr(after), rows: rows);
}

/// Arti singkat beta untuk tile Ringkasan (tanpa angka nol bila data kurang: pemanggil cek `null`).
String betaMeaning(double beta) => switch (beta) {
  < 0 => 'Cenderung berlawanan',
  < 0.3 => 'Hampir tidak terpengaruh',
  < 0.7 => 'Sedikit terpengaruh',
  < 1.2 => 'Hampir searah',
  _ => 'Lebih liar dari pasar',
};
