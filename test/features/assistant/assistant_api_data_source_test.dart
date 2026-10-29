import 'package:arah/core/network/api_client.dart';
import 'package:arah/core/storage/token_storage.dart';
import 'package:arah/features/assistant/data/datasources/assistant_remote_data_source.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mencatat request dan membalas seperti backend (`{ data }` sudah di-unwrap ApiClient).
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test', tokenStorage: const TokenStorage(FlutterSecureStorage()));
  final calls = <(String, Object?)>[];

  @override
  Future<dynamic> post(String path, {Object? body}) async {
    calls.add((path, body));
    return {
      'conversationId': 'c1',
      'message': {
        'id': 'm2',
        'role': 'assistant',
        'content': 'Kamu punya 10 lot BBCA.',
        'context': null,
        'createdAt': '2026-10-29T08:00:00.000Z',
      },
    };
  }
}

void main() {
  test('pesan pertama ke /conversations dengan konteks aset; balasan dipetakan', () async {
    final api = _FakeApi();
    final reply = await AssistantApiDataSource(api).sendMessage(
      conversationId: null,
      requestId: '1730188800000000-0',
      content: 'Berapa lot BBCA saya?',
      context: const AssetContext(symbol: 'BBCA', exchange: 'IDX'),
    );

    expect(api.calls.single.$1, '/api/mobile/conversations');
    expect(api.calls.single.$2, {
      'requestId': '1730188800000000-0',
      'content': 'Berapa lot BBCA saya?',
      'context': {'symbol': 'BBCA', 'exchange': 'IDX'},
    });
    expect(reply.conversationId, 'c1');
    expect(reply.message.id, 'm2');
    expect(reply.message.role, ChatRole.assistant);
    expect(reply.message.content, 'Kamu punya 10 lot BBCA.');
    expect(reply.message.createdAt, DateTime.parse('2026-10-29T08:00:00.000Z'));
  });

  test('pesan lanjutan ke /conversations/:id/messages, tanpa field context', () async {
    final api = _FakeApi();
    await AssistantApiDataSource(
      api,
    ).sendMessage(conversationId: 'c1', requestId: 'r2', content: 'Kalau dijual?');

    expect(api.calls.single.$1, '/api/mobile/conversations/c1/messages');
    expect(api.calls.single.$2, {'requestId': 'r2', 'content': 'Kalau dijual?'});
  });
}
