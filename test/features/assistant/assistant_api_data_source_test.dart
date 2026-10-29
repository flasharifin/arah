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

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add((path, query));
    if (path == '/api/mobile/conversations') {
      return [
        {
          'id': 'c1',
          'title': 'Soal BBCA',
          'createdAt': '2026-10-28T08:00:00.000Z',
          'updatedAt': '2026-10-29T08:00:00.000Z',
        },
      ];
    }
    return [
      {
        'id': 'm1',
        'role': 'user',
        'content': 'Berapa lot BBCA?',
        'context': 'BBCA:IDX',
        'createdAt': '2026-10-29T07:59:00.000Z',
      },
      {
        'id': 'm2',
        'role': 'assistant',
        'content': '10 lot.',
        'context': null,
        'createdAt': '2026-10-29T08:00:00.000Z',
      },
    ];
  }

  @override
  Future<dynamic> patch(String path, {Object? body}) async => calls.add((path, body));

  @override
  Future<dynamic> delete(String path, {Object? body}) async => calls.add((path, body));
}

void main() {
  test('riwayat: daftar, isi (peran user/assistant), ubah nama, hapus', () async {
    final api = _FakeApi();
    final source = AssistantApiDataSource(api);

    final list = await source.listConversations();
    expect(
      list.single,
      ConversationSummary(
        id: 'c1',
        title: 'Soal BBCA',
        updatedAt: DateTime.parse('2026-10-29T08:00:00.000Z'),
      ),
    );

    final messages = await source.fetchMessages('c1');
    expect(messages.map((m) => (m.id, m.role, m.content)), [
      ('m1', ChatRole.user, 'Berapa lot BBCA?'),
      ('m2', ChatRole.assistant, '10 lot.'),
    ]);
    expect(api.calls[1].$1, '/api/mobile/conversations/c1/messages');
    expect(api.calls[1].$2, {'limit': '100'});

    await source.renameConversation('c1', 'Judul baru');
    await source.deleteConversation('c1');
    expect(api.calls[2].$1, '/api/mobile/conversations/c1');
    expect(api.calls[2].$2, {'title': 'Judul baru'});
    expect(api.calls[3], ('/api/mobile/conversations/c1', null));
  });

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
