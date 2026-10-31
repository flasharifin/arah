import 'dart:math';

import 'package:arah/features/portfolio/domain/entities/position.dart';

// Rumus alat kalkulator, disalin dari komponen web (src/components/features/portfolio/*) supaya hasil sama.

/// Biaya transaksi IDX bawaan web: beli 0,15%, jual 0,25%.
const idxBuyFee = 0.0015;
const idxSellFee = 0.0025;

/// Harga impas setelah biaya; US/Crypto tanpa biaya bawaan (sama dengan `bepWithFee` web).
double breakEvenPrice(double avgPrice, Exchange exchange) =>
    exchange == Exchange.idx ? avgPrice * (1 + idxBuyFee) / (1 - idxSellFee) : avgPrice;

typedef LotResult = ({double quantity, double units, double cost, double fee, double total, double left, double bep});

/// Kalkulator lot: berapa yang terbeli dari [budget] di [price]. IDX per lot (100 lembar) dengan biaya
/// beli IDX; US/Crypto pecahan 4 desimal dengan [feePercent]. `null` = tidak cukup untuk 1 lot/unit.
/// Beda dengan web: jumlah IDX memperhitungkan biaya beli supaya sisa dana tidak minus.
LotResult? lotCalc({
  required Exchange exchange,
  required double budget,
  required double price,
  double feePercent = 0.15,
}) {
  if (budget <= 0 || price <= 0) return null;
  final isIdx = exchange == Exchange.idx;
  final fee = isIdx ? idxBuyFee : feePercent / 100;
  final double quantity = isIdx
      ? (budget / (price * 100 * (1 + fee))).floorToDouble()
      : (budget / (price * (1 + fee)) * 10000).floorToDouble() / 10000;
  if (quantity <= 0) return null;
  final units = quantity * exchange.unitsPerQuantity;
  final cost = units * price;
  return (
    quantity: quantity,
    units: units,
    cost: cost,
    fee: cost * fee,
    total: cost * (1 + fee),
    left: budget - cost * (1 + fee),
    bep: isIdx ? breakEvenPrice(price, exchange) : price * (1 + fee),
  );
}

typedef SizingResult = ({double quantity, double capitalIdr, double maxLossIdr, double riskPercent});

/// Position sizing: jumlah lot/unit agar rugi saat kena stop loss ≤ [riskPercent] dari [portfolioIdr].
/// `null` = input tidak valid (entry harus di atas stop loss).
SizingResult? positionSizing({
  required Exchange exchange,
  required double portfolioIdr,
  required double entry,
  required double stopLoss,
  required double riskPercent,
  required double usdToIdr,
}) {
  if (entry <= 0 || stopLoss <= 0 || entry <= stopLoss || riskPercent <= 0) return null;
  final toIdr = exchange == Exchange.idx ? 1.0 : usdToIdr;
  final riskPerUnit = entry - stopLoss;
  final maxRisk = portfolioIdr * riskPercent / 100;
  final unitsByRisk = (maxRisk / (riskPerUnit * toIdr)).floorToDouble();
  final quantity = exchange == Exchange.idx ? (unitsByRisk / 100).floorToDouble() : unitsByRisk;
  final units = quantity * exchange.unitsPerQuantity;
  final maxLoss = units * riskPerUnit * toIdr;
  return (
    quantity: quantity,
    capitalIdr: units * entry * toIdr,
    maxLossIdr: maxLoss,
    riskPercent: portfolioIdr > 0 ? maxLoss / portfolioIdr * 100 : 0,
  );
}

typedef AveragingResult = ({double newAvg, double newBep, double percentToBep, double extraCost});

/// Simulasi tambah [extraQuantity] lot/unit di [price] → harga rata-rata & BEP baru (sama dengan web).
AveragingResult averaging(Position p, {required double extraQuantity, required double price}) {
  final extraUnits = extraQuantity * p.exchange.unitsPerQuantity;
  final totalUnits = p.units + extraUnits;
  final newAvg = totalUnits > 0 ? (p.units * p.avgPrice.amount + extraUnits * price) / totalUnits : 0.0;
  final newBep = breakEvenPrice(newAvg, p.exchange);
  return (
    newAvg: newAvg,
    newBep: newBep,
    percentToBep: price > 0 ? (newBep - price) / price * 100 : 0,
    extraCost: extraUnits * price,
  );
}

typedef FiResult = ({double fiNumber, double? years, List<({int year, double value})> projections});

/// Financial independence: FI number = pengeluaran tahunan / 4%. Tahun menuju FI disimulasikan bulanan.
/// Beda dengan web: dicari sampai 60 tahun (web berhenti di 60 bulan, jadi target >5 tahun tampil "tidak tercapai").
FiResult fiCalc({
  required double currentIdr,
  required double monthlyExpense,
  required double monthlySaving,
  required double annualReturnPercent,
}) {
  final rMonthly = annualReturnPercent / 100 / 12;
  final fiNumber = monthlyExpense * 12 / 0.04;
  double? years;
  if (monthlyExpense > 0) {
    if (currentIdr >= fiNumber) {
      years = 0;
    } else {
      var pv = currentIdr;
      for (var n = 1; n <= 720; n++) {
        pv = pv * (1 + rMonthly) + monthlySaving;
        if (pv >= fiNumber) {
          years = n / 12;
          break;
        }
      }
    }
  }
  return (
    fiNumber: fiNumber,
    years: years,
    projections: [
      for (final year in const [5, 10, 15, 20, 25, 30])
        (
          year: year,
          value:
              currentIdr * pow(1 + rMonthly, year * 12) +
              (rMonthly > 0
                  ? monthlySaving * (pow(1 + rMonthly, year * 12) - 1) / rMonthly
                  : monthlySaving * year * 12),
        ),
    ],
  );
}

typedef RebalanceRow = ({Exchange exchange, double actualPercent, double targetPercent, double actionIdr});

/// Rebalancing per bursa: [actionIdr] positif = tambah, negatif = kurangi, agar sesuai [targets] (jumlah 100%)
/// setelah ditambah [newFundsIdr]. `null` bila target tidak berjumlah 100%.
List<RebalanceRow>? rebalance(Map<Exchange, double> valueIdr, Map<Exchange, double> targets, {double newFundsIdr = 0}) {
  if ((targets.values.fold(0.0, (s, v) => s + v) - 100).abs() >= 0.01) return null;
  final total = valueIdr.values.fold(0.0, (s, v) => s + v);
  return [
    for (final e in Exchange.values)
      (
        exchange: e,
        actualPercent: total > 0 ? (valueIdr[e] ?? 0) / total * 100 : 0,
        targetPercent: targets[e] ?? 0,
        actionIdr: (total + newFundsIdr) * (targets[e] ?? 0) / 100 - (valueIdr[e] ?? 0),
      ),
  ];
}
