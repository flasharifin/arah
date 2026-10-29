import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';

abstract interface class DividendRemoteDataSource {
  Future<List<Dividend>> list();
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

/// `/api/dividends` (urut tanggal bayar terbaru, yang belum ada tanggal di akhir).
class DividendApiDataSource implements DividendRemoteDataSource {
  const DividendApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<List<Dividend>> list() async => [
    for (final d in (await _api.get('/api/dividends') as List<dynamic>).cast<Map<String, dynamic>>())
      Dividend(
        id: d['id'] as String,
        symbol: d['stockCode'] as String,
        dps: num.parse('${d['dps']}').toDouble(), // Decimal Prisma → string
        exDate: _date(d['exDate']),
        paymentDate: _date(d['paymentDate']),
        received: d['receivedAmount'] == null
            ? null
            : Money.idr(num.parse('${d['receivedAmount']}').toDouble()),
      ),
  ];
}

/// Data ilustrasi S11.
class DividendFixtureDataSource implements DividendRemoteDataSource {
  @override
  Future<List<Dividend>> list() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    return [
      Dividend(id: 'd1', symbol: 'BBCA', dps: 270, exDate: now.add(const Duration(days: 10))),
      Dividend(
        id: 'd2',
        symbol: 'BBCA',
        dps: 175,
        paymentDate: DateTime(now.year, 1, 15),
        received: const Money.idr(1575000),
      ),
    ];
  }
}
