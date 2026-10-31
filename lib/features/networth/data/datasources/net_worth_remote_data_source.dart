import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/journal/domain/entities/journal.dart' show dayKey;
import 'package:arah/features/networth/domain/entities/net_worth.dart';

abstract interface class NetWorthRemoteDataSource {
  Future<NetWorth> fetchNetWorth();

  /// [id] `null` = tambah.
  Future<void> saveEntry(ManualEntry entry, {String? id});
  Future<void> removeEntry(WealthKind kind, String id);

  /// Total dihitung server dari data saat ini.
  Future<void> createSnapshot();
  Future<void> removeSnapshot(String id);

  /// Target kekayaan di `/api/settings` (sama dengan form target web).
  Future<void> saveGoal(WealthGoal goal);
}

String _path(WealthKind kind) => kind == WealthKind.asset ? '/api/networth/assets' : '/api/networth/liabilities';

/// Aset & utang dari `/api/summary` (nilai sudah dikonversi ke rupiah oleh server) + target dari `/api/settings`
/// + snapshot dari `/api/networth/snapshot`.
class NetWorthApiDataSource implements NetWorthRemoteDataSource {
  const NetWorthApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<NetWorth> fetchNetWorth() async {
    final results = await Future.wait([
      _api.get('/api/summary'),
      _api.get('/api/settings'),
      _api.get('/api/networth/snapshot'),
    ]);
    final s = results[0] as Map<String, dynamic>;
    final settings = results[1] as Map<String, dynamic>;
    final positionCount = (s['portfolioSummary'] as Map<String, dynamic>)['count'] as num;
    double num_(Object? v) => (v as num).toDouble();
    double decimal(Object? v) => num.parse('$v').toDouble(); // Decimal Prisma → string

    return NetWorth(
      asOf: DateTime.parse((s['asOf'] as Map<String, dynamic>)['computedAt'] as String),
      assets: [
        if (positionCount > 0)
          WealthItem(
            id: 'portfolio',
            name: 'Portofolio investasi',
            category: WealthCategory.portfolio,
            value: Money.idr(num_(s['portfolioValueIDR'])),
            isAutomatic: true,
          ),
        for (final a in (s['manualAssets'] as List<dynamic>).cast<Map<String, dynamic>>())
          WealthItem(
            id: a['id'] as String,
            name: a['name'] as String,
            category: _category(a['category'] as String),
            value: Money.idr(num_(a['valueIDR'])),
            entry: ManualEntry(
              kind: WealthKind.asset,
              name: a['name'] as String,
              category: a['category'] as String,
              amount: num_(a['value']),
              currency: a['currency'] as String? ?? 'IDR',
              note: a['note'] as String?,
            ),
          ),
      ],
      liabilities: [
        for (final l in (s['liabilityItems'] as List<dynamic>).cast<Map<String, dynamic>>())
          WealthItem(
            id: l['id'] as String,
            name: l['name'] as String,
            category: WealthCategory.debt,
            value: Money.idr(num_(l['amountIDR'])),
            entry: ManualEntry(
              kind: WealthKind.liability,
              name: l['name'] as String,
              category: l['category'] as String,
              amount: num_(l['amountIDR']),
              note: l['note'] as String?,
            ),
          ),
      ],
      snapshots: [
        for (final n in (results[2] as List<dynamic>).cast<Map<String, dynamic>>().reversed)
          NetWorthSnapshot(
            id: n['id'] as String,
            date: DateTime.parse(n['snapshotDate'] as String),
            totalAssets: Money.idr(decimal(n['totalAssets'])),
            totalLiabilities: Money.idr(decimal(n['totalLiabilities'])),
            netValue: Money.idr(decimal(n['netValue'])),
          ),
      ],
      goal: WealthGoal(
        name: settings['goalName'] as String? ?? 'Target kekayaan',
        target: Money.idr(num_(settings['wealthTarget'])),
        deadline: switch (settings['goalDeadline']) {
          final String d => DateTime.parse(d),
          _ => null,
        },
        monthlyContribution: switch (settings['goalMonthlyContrib']) {
          final num v => Money.idr(v.toDouble()),
          _ => null,
        },
        expectedReturnPercent: (settings['goalReturnPct'] as num?)?.toDouble(),
      ),
    );
  }

  /// `note` selalu dikirim: string kosong = hapus catatan (server tidak mengubah catatan bila `note` absen).
  @override
  Future<void> saveEntry(ManualEntry e, {String? id}) {
    final body = {
      'name': e.name.trim(),
      'category': e.category,
      'note': e.note?.trim() ?? '',
      if (e.kind == WealthKind.asset) ...{'value': e.amount, 'currency': e.currency} else 'amount': e.amount,
    };
    return id == null ? _api.post(_path(e.kind), body: body) : _api.put('${_path(e.kind)}/$id', body: body);
  }

  @override
  Future<void> removeEntry(WealthKind kind, String id) => _api.delete('${_path(kind)}/$id');

  @override
  Future<void> createSnapshot() => _api.post('/api/networth/snapshot');

  @override
  Future<void> removeSnapshot(String id) => _api.delete('/api/networth/snapshot/$id');

  /// Semua field dikirim supaya yang dikosongkan ikut terhapus (server: `null` = hapus).
  @override
  Future<void> saveGoal(WealthGoal g) => _api.put(
    '/api/settings',
    body: {
      'goalName': g.name.trim(),
      'wealthTarget': g.target.amount,
      'goalDeadline': g.deadline == null ? null : dayKey(g.deadline!),
      'goalMonthlyContrib': g.monthlyContribution?.amount,
      'goalReturnPct': g.expectedReturnPercent,
    },
  );

  // Enum AssetCategory backend; stock/crypto manual (di luar portofolio) masuk Lainnya.
  static WealthCategory _category(String backend) => switch (backend) {
    'cash' => WealthCategory.cash,
    'mutual_fund' => WealthCategory.mutualFund,
    'property' => WealthCategory.property,
    'gold' => WealthCategory.gold,
    'defi' => WealthCategory.defi,
    _ => WealthCategory.other,
  };
}

/// Fixture S07: aset 148,45 jt − utang 20 jt = 128,45 jt; target 1 M. Perubahan disimpan di memori.
class NetWorthFixtureDataSource implements NetWorthRemoteDataSource {
  // Kurs ilustrasi untuk konversi di fixture (di API, server yang mengonversi).
  static const _usdIdr = 16000.0;
  static const _goldIdrPerGram = 2000000.0;
  static const _portfolio = Money.idr(98450000);

  final _entries = <String, ManualEntry>{
    'cash': const ManualEntry(
      kind: WealthKind.asset,
      name: 'Tabungan',
      category: 'cash',
      amount: 30000000,
      note: 'BCA',
    ),
    'gold': const ManualEntry(kind: WealthKind.asset, name: 'Emas', category: 'gold', amount: 10, currency: 'GOLD'),
    'vehicle': const ManualEntry(
      kind: WealthKind.liability,
      name: 'Cicilan kendaraan',
      category: 'vehicle_loan',
      amount: 20000000,
    ),
  };
  final _snapshots = <NetWorthSnapshot>[];
  var _nextId = 0;

  static double _idr(ManualEntry e) => switch (e.currency) {
    'USD' => e.amount * _usdIdr,
    'GOLD' => e.amount * _goldIdrPerGram,
    _ => e.amount,
  };

  NetWorth _current() => NetWorth(
    asOf: DateTime.now(),
    assets: [
      const WealthItem(
        id: 'portfolio',
        name: 'Portofolio investasi',
        category: WealthCategory.portfolio,
        value: _portfolio,
        isAutomatic: true,
      ),
      for (final MapEntry(key: id, value: e) in _entries.entries)
        if (e.kind == WealthKind.asset)
          WealthItem(
            id: id,
            name: e.name,
            category: NetWorthApiDataSource._category(e.category),
            value: Money.idr(_idr(e)),
            entry: e,
          ),
    ],
    liabilities: [
      for (final MapEntry(key: id, value: e) in _entries.entries)
        if (e.kind == WealthKind.liability)
          WealthItem(id: id, name: e.name, category: WealthCategory.debt, value: Money.idr(e.amount), entry: e),
    ],
    snapshots: List.of(_snapshots),
    goal: _goal,
  );

  var _goal = WealthGoal(
    name: 'Road to 1M',
    target: const Money.idr(1000000000),
    deadline: DateTime(2035, 12, 31),
    monthlyContribution: const Money.idr(5000000),
    expectedReturnPercent: 10,
  );

  @override
  Future<void> saveGoal(WealthGoal goal) async => _goal = goal;

  @override
  Future<NetWorth> fetchNetWorth() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return _current();
  }

  @override
  Future<void> saveEntry(ManualEntry entry, {String? id}) async => _entries[id ?? 'manual-${_nextId++}'] = ManualEntry(
    kind: entry.kind,
    name: entry.name.trim(),
    category: entry.category,
    amount: entry.amount,
    currency: entry.currency,
    note: entry.note?.trim(),
  );

  @override
  Future<void> removeEntry(WealthKind kind, String id) async => _entries.remove(id);

  @override
  Future<void> createSnapshot() async {
    final n = _current();
    _snapshots.insert(
      0,
      NetWorthSnapshot(
        id: 'snap-${_nextId++}',
        date: DateTime.now(),
        totalAssets: n.totalAssets,
        totalLiabilities: n.totalLiabilities,
        netValue: n.netWorth,
      ),
    );
  }

  @override
  Future<void> removeSnapshot(String id) async => _snapshots.removeWhere((s) => s.id == id);
}
