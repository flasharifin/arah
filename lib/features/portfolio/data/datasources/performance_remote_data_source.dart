import 'dart:math';

import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/portfolio/domain/entities/performance.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';

abstract interface class PerformanceRemoteDataSource {
  /// Urut tanggal naik, maksimal 1 tahun terakhir.
  Future<List<DailyPerformance>> fetchDaily();

  /// Urut tanggal jual terbaru dulu.
  Future<List<SaleRecord>> fetchSales();
}

double _num(Object? v) => num.parse('$v').toDouble(); // Decimal Prisma → string
double? _numOrNull(Object? v) => v == null ? null : _num(v);

/// Tanggal backend = tengah malam UTC dari `YYYY-MM-DD`; ambil tanggalnya saja sebagai tanggal lokal.
DateTime _day(String iso) => DateTime.parse(iso.substring(0, 10));

class PerformanceApiDataSource implements PerformanceRemoteDataSource {
  const PerformanceApiDataSource(this._api);
  final ApiClient _api;

  /// `?limit=366` cukup untuk periode 1T (server membatasi 366).
  @override
  Future<List<DailyPerformance>> fetchDaily() async {
    final rows = await _api.get('/api/pnl/daily', query: {'limit': '366'}) as List<dynamic>;
    return [
      for (final p in rows.cast<Map<String, dynamic>>())
        DailyPerformance(
          date: _day(p['date'] as String),
          portfolioValue: Money.idr(_num(p['portfolioValue'])),
          pnl: Money.idr(_num(p['pnl'])),
          pnlPercent: _num(p['pnlPct']),
          ihsgChange: _numOrNull(p['ihsgChange']),
          sp500Change: _numOrNull(p['sp500Change']),
          btcChange: _numOrNull(p['btcChange']),
        ),
    ];
  }

  @override
  Future<List<SaleRecord>> fetchSales() async {
    final rows = await _api.get('/api/portfolio/sales') as List<dynamic>;
    return [
      for (final s in rows.cast<Map<String, dynamic>>())
        () {
          final currency = s['currency'] == 'USD' ? Currency.usd : Currency.idr;
          final cost = _num(s['totalCost']);
          final pnl = _num(s['realizedPnl']);
          return SaleRecord(
            id: s['id'] as String,
            symbol: s['stockCode'] as String,
            exchange: Exchange.fromCode(s['exchange'] as String),
            broker: s['platform'] as String? ?? '',
            quantity: _num(s['lotSold']),
            salePrice: Money(_num(s['salePrice']), currency),
            proceeds: Money(_num(s['totalProceeds']), currency),
            realizedPnl: Money(pnl, currency),
            realizedPercent: cost == 0 ? 0 : pnl / cost * 100,
            date: _day(s['saleDate'] as String),
            note: s['note'] as String?,
          );
        }(),
    ];
  }
}

/// Data ilustrasi S03 Kinerja/Riwayat: 400 hari deterministik (akhir pekan tanpa data benchmark).
class PerformanceFixtureDataSource implements PerformanceRemoteDataSource {
  @override
  Future<List<DailyPerformance>> fetchDaily() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final today = DateTime.now();
    var value = 90000000.0;
    return [
      for (var i = 365; i >= 1; i--)
        () {
          final date = DateTime(today.year, today.month, today.day - i);
          final weekend = date.weekday >= DateTime.saturday;
          final pct = weekend ? 0.0 : 0.6 * sin(i * 0.7) + 0.08;
          final pnl = value * pct / 100;
          value += pnl;
          return DailyPerformance(
            date: date,
            portfolioValue: Money.idr(value.roundToDouble()),
            pnl: Money.idr(pnl.roundToDouble()),
            pnlPercent: pct,
            ihsgChange: weekend ? null : 0.5 * sin(i * 0.9) + 0.03,
            sp500Change: weekend ? null : 0.7 * cos(i * 0.5) + 0.05,
            btcChange: 1.8 * sin(i * 0.3) + 0.1, // kripto diperdagangkan setiap hari
          );
        }(),
    ];
  }

  @override
  Future<List<SaleRecord>> fetchSales() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final today = DateTime.now();
    return [
      SaleRecord(
        id: 'sale-1',
        symbol: 'ASII',
        exchange: Exchange.idx,
        broker: 'Stockbit',
        quantity: 10,
        salePrice: const Money.idr(5200),
        proceeds: const Money.idr(5200000),
        realizedPnl: const Money.idr(450000),
        realizedPercent: 9.47,
        date: DateTime(today.year, today.month, today.day - 12),
        note: 'Ambil untung sebagian',
      ),
      SaleRecord(
        id: 'sale-2',
        symbol: 'NVDA',
        exchange: Exchange.us,
        broker: 'Gotrade',
        quantity: 2,
        salePrice: const Money.usd(118.5),
        proceeds: const Money.usd(237),
        realizedPnl: const Money.usd(-31.4),
        realizedPercent: -11.7,
        date: DateTime(today.year, today.month, today.day - 60),
      ),
      SaleRecord(
        id: 'sale-3',
        symbol: 'UNVR',
        exchange: Exchange.idx,
        broker: 'Ajaib',
        quantity: 30,
        salePrice: const Money.idr(2800),
        proceeds: const Money.idr(8400000),
        realizedPnl: const Money.idr(-1200000),
        realizedPercent: -12.5,
        date: DateTime(today.year, today.month, today.day - 200),
      ),
    ];
  }
}
