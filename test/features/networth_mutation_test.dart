import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/networth/data/datasources/net_worth_remote_data_source.dart';
import 'package:arah/features/networth/domain/entities/net_worth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Merekam request mutasi (method, path, body).
class _RecordingApi extends ApiClient {
  _RecordingApi() : super(baseUrl: 'http://test', tokenStorage: const TokenStorage(FlutterSecureStorage()));
  final calls = <(String, String, Object?)>[];

  @override
  Future<dynamic> post(String path, {Object? body}) async => calls.add(('POST', path, body));
  @override
  Future<dynamic> put(String path, {Object? body}) async => calls.add(('PUT', path, body));
  @override
  Future<dynamic> delete(String path, {Object? body}) async => calls.add(('DELETE', path, body));
}

void main() {
  test('body sesuai assetSchema/liabilitySchema backend; snapshot tanpa angka client', () async {
    final api = _RecordingApi();
    final ds = NetWorthApiDataSource(api);
    await ds.saveEntry(
      const ManualEntry(kind: WealthKind.asset, name: ' Emas ', category: 'gold', amount: 10, currency: 'GOLD'),
    );
    await ds.saveEntry(
      const ManualEntry(kind: WealthKind.liability, name: 'KPR', category: 'mortgage', amount: 250000000),
      id: 'l1',
    );
    await ds.removeEntry(WealthKind.asset, 'a1');
    await ds.createSnapshot();
    await ds.removeSnapshot('n1');

    // Record berisi Map tidak sama secara ==; bandingkan per bagian.
    expect(
      [for (final c in api.calls) (c.$1, c.$2)],
      [
        ('POST', '/api/networth/assets'),
        ('PUT', '/api/networth/liabilities/l1'),
        ('DELETE', '/api/networth/assets/a1'),
        ('POST', '/api/networth/snapshot'),
        ('DELETE', '/api/networth/snapshot/n1'),
      ],
    );
    expect(api.calls[0].$3, {'name': 'Emas', 'category': 'gold', 'value': 10.0, 'currency': 'GOLD'});
    expect(api.calls[1].$3, {'name': 'KPR', 'category': 'mortgage', 'amount': 250000000.0});
    expect(api.calls[3].$3, isNull); // total snapshot dihitung server
  });
}
