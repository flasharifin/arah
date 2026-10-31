import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/dca/domain/entities/dca.dart';

abstract interface class DcaRemoteDataSource {
  Future<DcaOverview> overview();
  Future<void> recordExecution(DcaExecution execution);
  Future<void> savePlan(DcaPlanDraft draft, {String? id});
  Future<void> deletePlan(String id);
}

Map<String, Object?> _planBody(DcaPlanDraft d) => {
  'targetPrice': d.targetPrice,
  'budget': d.budget,
  'frequency': d.frequency,
  'nextDate': d.nextDate?.toIso8601String(),
};

double _num(Object? v) => num.parse('$v').toDouble(); // Decimal Prisma bisa datang sebagai string

/// `/api/dca/plans` + `/api/dca/transactions`. POST transaksi menambah lot posisi di server.
class DcaApiDataSource implements DcaRemoteDataSource {
  const DcaApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<DcaOverview> overview() async {
    final results = await Future.wait([_api.get('/api/dca/plans'), _api.get('/api/dca/transactions')]);
    return DcaOverview(
      plans: [
        for (final p in (results[0] as List<dynamic>).cast<Map<String, dynamic>>())
          DcaPlan(
            id: p['id'] as String,
            portfolioId: p['portfolioId'] as String,
            symbol: p['stockCode'] as String,
            targetPrice: _num(p['targetPrice']),
            budget: _num(p['budget']),
            frequency: p['frequency'] as String? ?? 'monthly',
            isActive: p['isActive'] as bool? ?? true,
            nextDate: p['nextDate'] == null ? null : DateTime.parse(p['nextDate'] as String),
          ),
      ],
      records: [
        for (final t in (results[1] as List<dynamic>).cast<Map<String, dynamic>>())
          DcaRecord(
            id: t['id'] as String,
            symbol: t['stockCode'] as String,
            quantity: _num(t['lot']),
            price: _num(t['price']),
            total: _num(t['totalCost']),
            date: DateTime.parse(t['buyDate'] as String),
          ),
      ],
    );
  }

  @override
  Future<void> recordExecution(DcaExecution e) => _api.post(
    '/api/dca/transactions',
    body: {
      'portfolioId': e.plan.portfolioId,
      'stockCode': e.plan.symbol,
      'dcaPlanId': e.plan.id,
      'lot': e.quantity,
      'price': e.price,
      'buyDate': e.date.toIso8601String(),
      'requestId': e.requestId,
    },
  );

  @override
  Future<void> savePlan(DcaPlanDraft draft, {String? id}) => id == null
      ? _api.post(
          '/api/dca/plans',
          body: {..._planBody(draft), 'portfolioId': draft.portfolioId, 'stockCode': draft.symbol},
        )
      : _api.put('/api/dca/plans/$id', body: {..._planBody(draft), 'isActive': draft.isActive});

  @override
  Future<void> deletePlan(String id) => _api.delete('/api/dca/plans/$id');
}

/// Data ilustrasi S10, disimpan di memori.
class DcaFixtureDataSource implements DcaRemoteDataSource {
  final _plans = [
    DcaPlan(
      id: 'p1',
      portfolioId: 'bbca',
      symbol: 'BBCA',
      targetPrice: 9000,
      budget: 2000000,
      frequency: 'monthly',
      isActive: true,
      nextDate: DateTime(2026, 11, 25),
    ),
  ];
  final _records = [
    DcaRecord(
      id: 'r1',
      symbol: 'BBCA',
      quantity: 2,
      price: 9100,
      total: 1820000,
      date: DateTime(2026, 10, 25),
    ),
  ];
  final _seen = <String>{};

  @override
  Future<DcaOverview> overview() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return DcaOverview(plans: List.of(_plans), records: List.of(_records));
  }

  @override
  Future<void> recordExecution(DcaExecution e) async {
    if (!_seen.add(e.requestId)) return; // sama seperti server: kirim ulang tidak dicatat dua kali
    final units = e.quantity * 100; // fixture hanya punya rencana IDX (1 lot = 100 lembar)
    _records.insert(
      0,
      DcaRecord(
        id: e.requestId,
        symbol: e.plan.symbol,
        quantity: e.quantity,
        price: e.price,
        total: units * e.price,
        date: e.date,
      ),
    );
  }

  @override
  Future<void> savePlan(DcaPlanDraft d, {String? id}) async {
    final plan = DcaPlan(
      id: id ?? 'p${_plans.length + 1}',
      portfolioId: d.portfolioId,
      symbol: d.symbol,
      targetPrice: d.targetPrice,
      budget: d.budget,
      frequency: d.frequency,
      isActive: d.isActive,
      nextDate: d.nextDate,
    );
    final i = _plans.indexWhere((p) => p.id == id);
    i < 0 ? _plans.insert(0, plan) : _plans[i] = plan;
  }

  @override
  Future<void> deletePlan(String id) async => _plans.removeWhere((p) => p.id == id);
}
