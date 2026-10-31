import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';

abstract interface class DividendRemoteDataSource {
  Future<List<Dividend>> list();
  Future<void> save(DividendDraft draft, {String? id});
  Future<void> remove(String id);
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);
double? _num(Object? v) => v == null ? null : num.parse('$v').toDouble(); // Decimal Prisma → string

/// `/api/dividends` (urut tanggal bayar terbaru, yang belum ada tanggal di akhir) dan `/:id`.
class DividendApiDataSource implements DividendRemoteDataSource {
  const DividendApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<List<Dividend>> list() async => [
    for (final d in (await _api.get('/api/dividends') as List<dynamic>).cast<Map<String, dynamic>>())
      Dividend(
        id: d['id'] as String,
        portfolioId: d['portfolioId'] as String,
        symbol: d['stockCode'] as String,
        dps: _num(d['dps'])!,
        taxPercent: _num(d['taxPct']) ?? 10,
        cumDate: _date(d['cumDate']),
        exDate: _date(d['exDate']),
        paymentDate: _date(d['paymentDate']),
        received: d['receivedAmount'] == null ? null : Money.idr(_num(d['receivedAmount'])!),
        note: d['note'] as String?,
      ),
  ];

  @override
  Future<void> save(DividendDraft d, {String? id}) {
    final body = {
      'dps': d.dps,
      'taxPct': d.taxPercent,
      'cumDate': d.cumDate?.toIso8601String(),
      'exDate': d.exDate?.toIso8601String(),
      'paymentDate': d.paymentDate?.toIso8601String(),
      'note': d.note,
    };
    return id == null
        ? _api.post('/api/dividends', body: {...body, 'portfolioId': d.portfolioId, 'stockCode': d.symbol})
        : _api.put('/api/dividends/$id', body: body);
  }

  @override
  Future<void> remove(String id) => _api.delete('/api/dividends/$id');
}

/// Data ilustrasi S11, disimpan di memori.
class DividendFixtureDataSource implements DividendRemoteDataSource {
  final _items = <Dividend>[
    Dividend(
      id: 'd1',
      portfolioId: 'bbca',
      symbol: 'BBCA',
      dps: 270,
      exDate: DateTime.now().add(const Duration(days: 10)),
    ),
    Dividend(
      id: 'd2',
      portfolioId: 'bbca',
      symbol: 'BBCA',
      dps: 175,
      paymentDate: DateTime(DateTime.now().year, 1, 15),
      received: const Money.idr(1575000),
    ),
  ];
  int _seq = 3;

  @override
  Future<List<Dividend>> list() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List.of(_items);
  }

  @override
  Future<void> save(DividendDraft d, {String? id}) async {
    final item = Dividend(
      id: id ?? 'd${_seq++}',
      portfolioId: d.portfolioId,
      symbol: d.symbol,
      dps: d.dps,
      taxPercent: d.taxPercent,
      cumDate: d.cumDate,
      exDate: d.exDate,
      paymentDate: d.paymentDate,
      // fixture: 100 lot × 100 lembar, seperti posisi BBCA ilustrasi
      received: Money.idr(10000 * d.dps * (1 - d.taxPercent / 100)),
      note: d.note,
    );
    final i = _items.indexWhere((x) => x.id == id);
    i < 0 ? _items.insert(0, item) : _items[i] = item;
  }

  @override
  Future<void> remove(String id) async => _items.removeWhere((d) => d.id == id);
}
