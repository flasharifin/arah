import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/cashflow/domain/entities/cashflow.dart';

abstract interface class CashflowRemoteDataSource {
  Future<CashflowOverview> overview(DateTime month);
  Future<CashMovementPage> movements({String? assetId, int days});
  Future<void> reverse(String movementId);
  Future<void> saveSettings(CashflowSettings settings);
}

double _n(Object? v) => (v as num).toDouble();
double? _nOrNull(Object? v) => (v as num?)?.toDouble();
Currency _currency(Object? v) => v == 'USD' ? Currency.usd : Currency.idr;
String _monthKey(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';
DateTime _parseMonth(String k) => DateTime(int.parse(k.substring(0, 4)), int.parse(k.substring(5, 7)));

CashMovement _movement(Map<String, dynamic> m) {
  final currency = _currency(m['currency']);
  return CashMovement(
    id: m['id'] as String,
    assetId: m['assetId'] as String,
    assetName: m['assetName'] as String,
    kind: CashMovementKind.parse(m['kind'] as String),
    title: m['title'] as String,
    amount: Money(_n(m['amount']), currency),
    amountIdr: _n(m['amountIdr']),
    balanceAfter: Money(_n(m['balanceAfter']), currency),
    date: DateTime.parse(m['date'] as String).toLocal(),
    reversal: m['reversal'] as bool? ?? false,
    reversed: m['reversed'] as bool? ?? false,
  );
}

CashflowMonth _month(Map<String, dynamic> s) => CashflowMonth(
  month: _parseMonth(s['month'] as String),
  salary: _n(s['salary']),
  dividends: _n(s['dividends']),
  otherIncome: _n(s['otherIncome']),
  totalIncome: _n(s['totalIncome']),
  invested: _n(s['invested']),
  cashDelta: _n(s['cashDelta']),
  expense: _n(s['expense']),
  saved: _n(s['saved']),
  hasData: s['hasData'] as bool? ?? true,
  savingsRatePercent: _nOrNull(s['savingsRatePct']),
);

/// `GET /api/cashflow?month=`, `GET /api/cashflow/movements`, `POST …/[id]/reverse`, pengaturan di `/api/settings`.
class CashflowApiDataSource implements CashflowRemoteDataSource {
  const CashflowApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<CashflowOverview> overview(DateTime month) async {
    final d = await _api.get('/api/cashflow', query: {'month': _monthKey(month)}) as Map<String, dynamic>;
    final e = d['emergency'] as Map<String, dynamic>;
    final st = d['settings'] as Map<String, dynamic>;
    final summary = d['summary'] as Map<String, dynamic>;
    return CashflowOverview(
      month: _parseMonth(d['month'] as String),
      summary: _month(summary),
      series: [for (final s in (d['series'] as List<dynamic>).cast<Map<String, dynamic>>()) _month(s)],
      assets: [
        for (final a in (d['assets'] as List<dynamic>).cast<Map<String, dynamic>>())
          CashAssetBalance(
            id: a['id'] as String,
            name: a['name'] as String,
            value: Money(_n(a['value']), _currency(a['currency'])),
            valueIdr: _n(a['valueIdr']),
            balances: [
              for (final b in (a['balances'] as List<dynamic>).cast<Map<String, dynamic>>())
                (month: _parseMonth(b['month'] as String), valueIdr: _nOrNull(b['valueIdr'])),
            ],
          ),
      ],
      emergency: EmergencyFund(
        targetMonths: (e['targetMonths'] as num).toInt(),
        totalIdr: _n(e['totalIdr']),
        basisMonths: (e['basisMonths'] as num?)?.toInt() ?? 0,
        avgExpense: _nOrNull(e['avgExpense']),
        coveredMonths: _nOrNull(e['coveredMonths']),
        shortfall: _nOrNull(e['shortfall']),
        monthsToFull: (e['monthsToFull'] as num?)?.toInt(),
      ),
      recent: [for (final m in (d['recent'] as List<dynamic>).cast<Map<String, dynamic>>()) _movement(m)],
      settings: CashflowSettings(
        monthlyIncome: _nOrNull(st['monthlyIncome']),
        incomeDay: (st['incomeDay'] as num?)?.toInt(),
        incomeAssetId: st['incomeAssetId'] as String?,
        emergencyMonths: (st['emergencyMonths'] as num?)?.toInt() ?? 6,
      ),
      plan: _nOrNull(summary['plan']),
      dataSince: d['dataSince'] == null ? null : DateTime.parse(d['dataSince'] as String).toLocal(),
    );
  }

  @override
  Future<CashMovementPage> movements({String? assetId, int days = 30}) async {
    final d =
        await _api.get('/api/cashflow/movements', query: {'assetId': ?assetId, 'days': '$days'})
            as Map<String, dynamic>;
    return CashMovementPage(
      currency: _currency(d['currency']),
      days: (d['days'] as num).toInt(),
      balance: [
        for (final b in (d['balance'] as List<dynamic>).cast<Map<String, dynamic>>())
          (date: DateTime.parse(b['date'] as String), value: _n(b['value'])),
      ],
      totalIn: _n(d['totalIn']),
      totalOut: _n(d['totalOut']),
      items: [for (final m in (d['items'] as List<dynamic>).cast<Map<String, dynamic>>()) _movement(m)],
      assetName: (d['asset'] as Map<String, dynamic>?)?['name'] as String?,
      truncated: d['truncated'] as bool? ?? false,
    );
  }

  @override
  Future<void> reverse(String movementId) => _api.post('/api/cashflow/movements/$movementId/reverse');

  @override
  Future<void> saveSettings(CashflowSettings s) => _api.put(
    '/api/settings',
    body: {
      'monthlyIncome': s.monthlyIncome,
      'incomeDay': s.incomeDay,
      'incomeAssetId': s.incomeAssetId,
      'emergencyMonths': s.emergencyMonths,
    },
  );
}

/// Data ilustrasi (sama dengan mockup Arus kas): gaji Rp15 jt tgl 25, aset Cash IDR / Cash USD / Saldo Flooq.
class CashflowFixtureDataSource implements CashflowRemoteDataSource {
  var _settings = const CashflowSettings(monthlyIncome: 15000000, incomeDay: 25, incomeAssetId: 'cash-idr');
  final _reversed = <String>{};

  static const _inc = [15.1, 15.0, 15.2, 15.0, 30.0, 15.1, 15.0, 15.1, 15.0, 15.1, 15.0, 15.12];
  static const _exp = [7.2, 8.1, 7.5, 6.9, 11.8, 7.4, 7.0, 7.6, 8.4, 7.1, 7.3, 7.77];

  List<CashMovement> get _items {
    final now = DateTime.now();
    CashMovement m(
      String id,
      CashMovementKind k,
      String title,
      String asset,
      double amount,
      double after,
      int daysAgo, {
      Currency c = Currency.idr,
      bool reversal = false,
    }) => CashMovement(
      id: id,
      assetId: asset == 'Cash USD'
          ? 'cash-usd'
          : asset == 'Saldo Flooq'
          ? 'flooq'
          : 'cash-idr',
      assetName: asset,
      kind: k,
      title: title,
      amount: Money(amount, c),
      amountIdr: c == Currency.usd ? amount * 16500 : amount,
      balanceAfter: Money(after, c),
      date: now.subtract(Duration(days: daysAgo)),
      reversal: reversal,
      reversed: _reversed.contains(id),
    );
    return [
      m('m5', CashMovementKind.manual, 'Penyesuaian manual', 'Cash IDR', -8247150, 26200000, 0),
      m('m4', CashMovementKind.purchase, 'Beli BBCA 2 lot', 'Cash IDR', -1902850, 34447150, 3),
      if (_reversed.contains('m4'))
        m(
          'm4r',
          CashMovementKind.purchase,
          'Batal: Beli BBCA 2 lot',
          'Cash IDR',
          1902850,
          36350000,
          0,
          reversal: true,
        ),
      m('m3', CashMovementKind.dividend, 'Dividen TLKM', 'Saldo Flooq', 120000, 3200000, 5),
      m('m2', CashMovementKind.income, 'Gaji Oktober', 'Cash IDR', 15000000, 36350000, 6),
      m('m1', CashMovementKind.dca, 'DCA AAPL 0.2 unit', 'Cash USD', -32.4, 690.2, 16, c: Currency.usd),
    ];
  }

  @override
  Future<CashflowOverview> overview(DateTime month) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final end = DateTime(month.year, month.month);
    final series = [
      for (var i = 0; i < 12; i++)
        () {
          final income = _inc[i] * 1e6, expense = _exp[i] * 1e6, saved = income - expense;
          return CashflowMonth(
            month: DateTime(end.year, end.month - 11 + i),
            salary: i == 4 ? 30e6 : 15e6,
            dividends: income - (i == 4 ? 30e6 : 15e6),
            otherIncome: 0,
            totalIncome: income,
            invested: 2.5e6,
            cashDelta: saved - 2.5e6,
            expense: expense,
            saved: saved,
            hasData: true,
            savingsRatePercent: saved / income * 100,
          );
        }(),
    ];
    List<({DateTime month, double? valueIdr})> bal(List<double> v) => [
      for (var i = 0; i < 6; i++) (month: DateTime(end.year, end.month - 5 + i), valueIdr: v[i] * 1e6),
    ];
    return CashflowOverview(
      month: end,
      summary: series.last,
      series: series,
      assets: [
        CashAssetBalance(
          id: 'cash-idr',
          name: 'Cash IDR',
          value: const Money.idr(26200000),
          valueIdr: 26.2e6,
          balances: bal([18, 19.5, 17, 21, 21.35, 26.2]),
        ),
        CashAssetBalance(
          id: 'cash-usd',
          name: 'Cash USD',
          value: const Money.usd(690.2),
          valueIdr: 11.4e6,
          balances: bal([8, 8, 9.6, 9.6, 11.2, 11.4]),
        ),
        CashAssetBalance(
          id: 'flooq',
          name: 'Saldo Flooq',
          value: const Money.idr(3200000),
          valueIdr: 3.2e6,
          balances: bal([2.1, 2.6, 3.0, 2.4, 2.9, 3.2]),
        ),
      ],
      emergency: const EmergencyFund(
        targetMonths: 6,
        totalIdr: 40.8e6,
        basisMonths: 3,
        avgExpense: 7.4e6,
        coveredMonths: 40.8 / 7.4,
        shortfall: 3.6e6,
        monthsToFull: 1,
      ),
      recent: _items.take(4).toList(),
      settings: _settings,
      plan: 7000000,
      dataSince: DateTime(end.year - 1, end.month),
    );
  }

  @override
  Future<CashMovementPage> movements({String? assetId, int days = 30}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final items = _items.where((m) => assetId == null || m.assetId == assetId).toList();
    final today = DateTime.now();
    return CashMovementPage(
      currency: assetId == 'cash-usd' ? Currency.usd : Currency.idr,
      days: days,
      balance: [
        for (var i = 0; i < days; i++)
          (
            date: DateTime(today.year, today.month, today.day - days + 1 + i),
            value: (i < days - 6
                ? 21.35e6
                : i < days - 3
                ? 36.35e6
                : i < days - 1
                ? 34.45e6
                : 26.2e6),
          ),
      ],
      totalIn: items.where((m) => m.amount.amount > 0).fold(0, (s, m) => s + m.amountIdr),
      totalOut: -items.where((m) => m.amount.amount < 0).fold(0.0, (s, m) => s + m.amountIdr),
      items: items,
      assetName: items.isEmpty || assetId == null ? null : items.first.assetName,
    );
  }

  @override
  Future<void> reverse(String movementId) async => _reversed.add(movementId);

  @override
  Future<void> saveSettings(CashflowSettings settings) async => _settings = settings;
}
