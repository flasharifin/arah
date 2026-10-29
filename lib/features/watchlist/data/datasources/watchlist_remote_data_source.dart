import 'package:arah/core/domain/money.dart';
import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/portfolio/domain/entities/position.dart';
import 'package:arah/features/watchlist/domain/entities/watch_item.dart';

abstract interface class WatchlistRemoteDataSource {
  Future<List<WatchItem>> list();
  Future<void> save(WatchDraft draft, {String? id});
  Future<void> remove(String id);
}

Currency _currencyOf(Exchange e) => e == Exchange.idx ? Currency.idr : Currency.usd;

/// `/api/watchlist` (GET diperkaya harga & jarak target dari server) dan `/api/watchlist/:id`.
class WatchlistApiDataSource implements WatchlistRemoteDataSource {
  const WatchlistApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<List<WatchItem>> list() async => [
    for (final j in (await _api.get('/api/watchlist') as List<dynamic>).cast<Map<String, dynamic>>())
      () {
        final exchange = Exchange.fromCode(j['exchange'] as String);
        final currency = j['currency'] == 'USD' ? Currency.usd : _currencyOf(exchange);
        Money? money(Object? v) => v == null ? null : Money(num.parse('$v').toDouble(), currency);
        return WatchItem(
          id: j['id'] as String,
          symbol: j['stockCode'] as String,
          exchange: exchange,
          status: WatchStatus.fromCode(j['status'] as String?),
          targetPrice: money(j['targetPrice']),
          lastPrice: money(j['lastPrice']),
          gapPercent: (j['gapPct'] as num?)?.toDouble(),
          note: j['note'] as String?,
        );
      }(),
  ];

  @override
  Future<void> save(WatchDraft draft, {String? id}) {
    final body = {'targetPrice': draft.targetPrice, 'status': draft.status.code, 'note': draft.note};
    return id == null
        ? _api.post(
            '/api/watchlist',
            body: {
              ...body,
              'stockCode': draft.symbol.trim().toUpperCase(),
              'exchange': draft.exchange.code,
              'currency': _currencyOf(draft.exchange) == Currency.usd ? 'USD' : 'IDR',
            },
          )
        : _api.put('/api/watchlist/$id', body: body);
  }

  @override
  Future<void> remove(String id) => _api.delete('/api/watchlist/$id');
}

/// Data ilustrasi S09, disimpan di memori supaya tambah/ubah/hapus bisa dicoba.
class WatchlistFixtureDataSource implements WatchlistRemoteDataSource {
  final _items = <WatchItem>[
    const WatchItem(
      id: 'w1',
      symbol: 'TLKM',
      exchange: Exchange.idx,
      status: WatchStatus.readyToBuy,
      targetPrice: Money.idr(2800),
      lastPrice: Money.idr(2950),
      gapPercent: 5.36,
      note: 'Tunggu koreksi ke area support',
    ),
    const WatchItem(
      id: 'w2',
      symbol: 'NVDA',
      exchange: Exchange.us,
      status: WatchStatus.observe,
      targetPrice: Money.usd(120),
    ),
  ];
  int _seq = 3;

  @override
  Future<List<WatchItem>> list() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return List.of(_items);
  }

  @override
  Future<void> save(WatchDraft draft, {String? id}) async {
    final currency = _currencyOf(draft.exchange);
    final existing = _items.where((i) => i.id == id).firstOrNull;
    final item = WatchItem(
      id: id ?? 'w${_seq++}',
      symbol: draft.symbol.trim().toUpperCase(),
      exchange: draft.exchange,
      status: draft.status,
      targetPrice: draft.targetPrice == null ? null : Money(draft.targetPrice!, currency),
      lastPrice: existing?.lastPrice,
      note: draft.note,
    );
    if (existing == null) {
      _items.insert(0, item);
    } else {
      _items[_items.indexOf(existing)] = item;
    }
  }

  @override
  Future<void> remove(String id) async => _items.removeWhere((i) => i.id == id);
}
