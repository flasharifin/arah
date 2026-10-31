import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/dca/data/datasources/dca_remote_data_source.dart';
import 'package:arah/features/dca/domain/entities/dca.dart';
import 'package:arah/features/dividends/data/datasources/dividend_remote_data_source.dart';
import 'package:arah/features/dividends/domain/entities/dividend.dart';
import 'package:arah/features/journal/data/datasources/journal_remote_data_source.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/watchlist/data/datasources/watchlist_remote_data_source.dart';
import 'package:arah/features/watchlist/domain/entities/watch_item.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Membalas GET per path (sudah di-unwrap dari `{ data }`) dan mencatat mutasi.
class _FakeApi extends ApiClient {
  _FakeApi(this.gets)
    : super(baseUrl: 'http://test', tokenStorage: const TokenStorage(FlutterSecureStorage()));
  final Map<String, Object?> gets;
  final writes = <(String, String, Object?)>[];

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => gets[path];
  @override
  Future<dynamic> post(String path, {Object? body}) async => writes.add(('POST', path, body));
  @override
  Future<dynamic> put(String path, {Object? body}) async => writes.add(('PUT', path, body));
  @override
  Future<dynamic> delete(String path, {Object? body}) async => writes.add(('DELETE', path, body));
}

void main() {
  test('watchlist: harga/jarak target dari server, harga hilang tetap null, body tambah & ubah', () async {
    final api = _FakeApi({
      '/api/watchlist': [
        {
          'id': 'w1',
          'stockCode': 'TLKM',
          'exchange': 'IDX',
          'currency': 'IDR',
          'targetPrice': 2800,
          'status': 'siap_beli',
          'note': 'tunggu',
          'lastPrice': 2950,
          'gapPct': 5.36,
        },
        {
          'id': 'w2',
          'stockCode': 'NVDA',
          'exchange': 'US',
          'currency': 'USD',
          'targetPrice': '120',
          'status': 'observasi',
          'note': null,
          'lastPrice': null,
          'gapPct': null,
        },
      ],
    });
    final source = WatchlistApiDataSource(api);
    final [tlkm, nvda] = await source.list();
    expect(
      (tlkm.status, tlkm.targetPrice, tlkm.lastPrice, tlkm.gapPercent),
      (WatchStatus.readyToBuy, const Money.idr(2800), const Money.idr(2950), 5.36),
    );
    expect(
      (nvda.exchange, nvda.targetPrice, nvda.lastPrice, nvda.gapPercent),
      (Exchange.us, const Money.usd(120), null, null),
    );

    const draft = WatchDraft(
      symbol: ' bbri ',
      exchange: Exchange.idx,
      status: WatchStatus.observe,
      targetPrice: 4500,
    );
    await source.save(draft);
    await source.save(draft, id: 'w1');
    await source.remove('w1');
    expect(api.writes[0].$1, 'POST');
    expect(api.writes[0].$3, {
      'targetPrice': 4500.0,
      'status': 'observasi',
      'note': null,
      'stockCode': 'BBRI',
      'exchange': 'IDX',
      'currency': 'IDR',
    });
    expect((api.writes[1].$1, api.writes[1].$2), ('PUT', '/api/watchlist/w1'));
    expect(api.writes[1].$3, {'targetPrice': 4500.0, 'status': 'observasi', 'note': null});
    expect((api.writes[2].$1, api.writes[2].$2), ('DELETE', '/api/watchlist/w1'));
  });

  test('DCA: Decimal string dipetakan, catat pelaksanaan mengirim requestId & id rencana', () async {
    final api = _FakeApi({
      '/api/dca/plans': [
        {
          'id': 'p1',
          'portfolioId': 'pf1',
          'stockCode': 'BBCA',
          'targetPrice': '9000.00',
          'budget': '2000000.00',
          'frequency': 'weekly',
          'nextDate': null,
          'isActive': true,
        },
      ],
      '/api/dca/transactions': [
        {
          'id': 't1',
          'stockCode': 'BBCA',
          'lot': '2',
          'price': '9100.00',
          'totalCost': '1820000.00',
          'buyDate': '2026-10-25T00:00:00.000Z',
        },
      ],
    });
    final source = DcaApiDataSource(api);
    final overview = await source.overview();
    final plan = overview.plans.single;
    expect(
      (plan.targetPrice, plan.budget, plan.frequencyLabel, plan.nextDate),
      (9000.0, 2000000.0, 'Mingguan', null),
    );
    expect((overview.records.single.quantity, overview.records.single.total), (2.0, 1820000.0));

    await source.recordExecution(
      DcaExecution(
        plan: plan,
        quantity: 1,
        price: 8900,
        date: DateTime.utc(2026, 10, 30),
        requestId: 'uuid-1',
      ),
    );
    expect(api.writes.single.$2, '/api/dca/transactions');
    expect(api.writes.single.$3, {
      'portfolioId': 'pf1',
      'stockCode': 'BBCA',
      'dcaPlanId': 'p1',
      'lot': 1.0,
      'price': 8900.0,
      'buyDate': '2026-10-30T00:00:00.000Z',
      'requestId': 'uuid-1',
    });
  });

  test('DCA: body buat, ubah (dengan isActive), dan hapus rencana', () async {
    final api = _FakeApi({});
    final source = DcaApiDataSource(api);
    final draft = DcaPlanDraft(
      portfolioId: 'pf1',
      symbol: 'BBCA',
      targetPrice: 9000,
      budget: 2000000,
      frequency: 'monthly',
      isActive: false,
      nextDate: DateTime.utc(2026, 11, 25),
    );
    await source.savePlan(draft);
    await source.savePlan(draft, id: 'p1');
    await source.deletePlan('p1');
    expect((api.writes[0].$1, api.writes[0].$2), ('POST', '/api/dca/plans'));
    expect(api.writes[0].$3, {
      'targetPrice': 9000.0,
      'budget': 2000000.0,
      'frequency': 'monthly',
      'nextDate': '2026-11-25T00:00:00.000Z',
      'portfolioId': 'pf1',
      'stockCode': 'BBCA',
    });
    expect((api.writes[1].$1, api.writes[1].$2), ('PUT', '/api/dca/plans/p1'));
    expect(api.writes[1].$3, {
      'targetPrice': 9000.0,
      'budget': 2000000.0,
      'frequency': 'monthly',
      'nextDate': '2026-11-25T00:00:00.000Z',
      'isActive': false,
    });
    expect((api.writes[2].$1, api.writes[2].$2), ('DELETE', '/api/dca/plans/p1'));
  });

  test('dividen: tanggal kosong tetap null, jumlah diterima rupiah, status dibayar dari tanggal', () async {
    final api = _FakeApi({
      '/api/dividends': [
        {
          'id': 'd1',
          'portfolioId': 'pf1',
          'stockCode': 'BBCA',
          'taxPct': '10.00',
          'dps': '270.0000',
          'exDate': null,
          'paymentDate': null,
          'receivedAmount': null,
        },
        {
          'id': 'd2',
          'portfolioId': 'pf1',
          'stockCode': 'BBCA',
          'taxPct': '0',
          'dps': '175',
          'exDate': '2026-01-05T00:00:00.000Z',
          'paymentDate': '2026-01-15T00:00:00.000Z',
          'receivedAmount': '1575000.00',
        },
      ],
    });
    final [upcoming, paid] = await DividendApiDataSource(api).list();
    expect((upcoming.dps, upcoming.paymentDate, upcoming.received), (270.0, null, null));
    expect(upcoming.isPaid(DateTime.utc(2026, 10, 30)), isFalse);
    expect((paid.received, paid.isPaid(DateTime.utc(2026, 10, 30))), (const Money.idr(1575000), true));
  });

  test('dividen: body tambah (dengan posisi), ubah, hapus; tanggal kosong dikirim null', () async {
    final api = _FakeApi({});
    final source = DividendApiDataSource(api);
    final draft = DividendDraft(
      portfolioId: 'pf1',
      symbol: 'BBCA',
      dps: 200,
      taxPercent: 10,
      exDate: DateTime.utc(2026, 11, 3),
    );
    await source.save(draft);
    await source.save(draft, id: 'd1');
    await source.remove('d1');
    final common = {
      'dps': 200.0,
      'taxPct': 10.0,
      'cumDate': null,
      'exDate': '2026-11-03T00:00:00.000Z',
      'paymentDate': null,
      'note': null,
    };
    expect((api.writes[0].$1, api.writes[0].$2), ('POST', '/api/dividends'));
    expect(api.writes[0].$3, {...common, 'portfolioId': 'pf1', 'stockCode': 'BBCA'});
    expect((api.writes[1].$1, api.writes[1].$2), ('PUT', '/api/dividends/d1'));
    expect(api.writes[1].$3, common);
    expect((api.writes[2].$1, api.writes[2].$2), ('DELETE', '/api/dividends/d1'));
  });

  test('jurnal: kontribusi per saham = perubahan hari ini / nilai porto sebelum perubahan', () async {
    final api = _FakeApi({
      '/api/daily-note': <dynamic>[],
      '/api/pnl/daily': <dynamic>[],
      '/api/summary': {
        'portfolioValueIDR': 100000000,
        'totalDailyChangeIDR': -450000,
        'dailyRows': [
          {'stockCode': 'BBCA', 'exchange': 'IDX', 'dailyChangeIDR': -300000},
          {'stockCode': 'TLKM', 'exchange': 'IDX', 'dailyChangeIDR': -150000},
        ],
      },
    });
    final [bbca, tlkm] = (await JournalApiDataSource(api).load()).today;
    expect((bbca.symbol, bbca.change), ('BBCA', const Money.idr(-300000)));
    expect(bbca.contributionPercent, closeTo(-300000 / 100450000 * 100, 1e-9)); // ≈ −0,2987%
    expect(tlkm.contributionPercent, closeTo(-150000 / 100450000 * 100, 1e-9));
  });

  test('jurnal: catatan & PnL dikunci per YYYY-MM-DD, simpan mengirim tanggal yang sama', () async {
    final api = _FakeApi({
      '/api/daily-note': [
        {'date': '2026-10-29T00:00:00.000Z', 'note': 'IHSG koreksi'},
      ],
      '/api/pnl/daily': [
        {
          'date': '2026-10-29T00:00:00.000Z',
          'portfolioValue': '98450000.00',
          'pnl': '-450000.00',
          'pnlPct': '-0.4500',
        },
      ],
    });
    final source = JournalApiDataSource(api);
    final data = await source.load();
    expect(data.notes, {'2026-10-29': 'IHSG koreksi'});
    expect(
      (data.pnl['2026-10-29']!.pnl, data.pnl['2026-10-29']!.pnlPercent),
      (const Money.idr(-450000), -0.45),
    );

    await source.saveNote('2026-10-30', 'Catatan baru');
    expect(api.writes.single.$2, '/api/daily-note');
    expect(api.writes.single.$3, {'date': '2026-10-30', 'note': 'Catatan baru'});
  });
}
