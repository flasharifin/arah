import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';

abstract interface class AssistantRemoteDataSource {
  Future<ChatReply> sendMessage({
    required String? conversationId,
    required String requestId,
    required String content,
    AssetContext? context,
  });

  Future<List<ConversationSummary>> listConversations();
  Future<List<ChatMessage>> fetchMessages(String conversationId);
  Future<void> renameConversation(String conversationId, String title);
  Future<void> deleteConversation(String conversationId);
}

ChatMessage _messageFromJson(Map<String, dynamic> m) => ChatMessage(
  id: m['id'] as String,
  role: m['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
  content: m['content'] as String,
  createdAt: DateTime.parse(m['createdAt'] as String),
);

/// `POST /api/mobile/conversations` (pesan pertama) atau `/api/mobile/conversations/:id/messages`.
/// Kirim ulang dengan [requestId] sama → server mengembalikan jawaban yang sama, tidak dobel.
class AssistantApiDataSource implements AssistantRemoteDataSource {
  const AssistantApiDataSource(this._api);
  final ApiClient _api;

  @override
  Future<ChatReply> sendMessage({
    required String? conversationId,
    required String requestId,
    required String content,
    AssetContext? context,
  }) async {
    final data =
        await _api.post(
              conversationId == null
                  ? '/api/mobile/conversations'
                  : '/api/mobile/conversations/$conversationId/messages',
              body: {
                'requestId': requestId,
                'content': content,
                if (context != null) 'context': {'symbol': context.symbol, 'exchange': context.exchange},
              },
            )
            as Map<String, dynamic>;
    return ChatReply(
      conversationId: data['conversationId'] as String,
      message: _messageFromJson(data['message'] as Map<String, dynamic>),
    );
  }

  @override
  Future<List<ConversationSummary>> listConversations() async => [
    for (final c
        in (await _api.get('/api/mobile/conversations') as List<dynamic>).cast<Map<String, dynamic>>())
      ConversationSummary(
        id: c['id'] as String,
        title: c['title'] as String,
        updatedAt: DateTime.parse(c['updatedAt'] as String),
      ),
  ];

  // shortcut: hanya 100 pesan terbaru (batas API); tambahkan muat lebih lama (?before=) bila percakapan panjang.
  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId) async => [
    for (final m
        in (await _api.get('/api/mobile/conversations/$conversationId/messages', query: {'limit': '100'})
                as List<dynamic>)
            .cast<Map<String, dynamic>>())
      _messageFromJson(m),
  ];

  @override
  Future<void> renameConversation(String conversationId, String title) =>
      _api.patch('/api/mobile/conversations/$conversationId', body: {'title': title});

  @override
  Future<void> deleteConversation(String conversationId) =>
      _api.delete('/api/mobile/conversations/$conversationId');
}

/// Balasan ilustrasi; bukan hasil pemanggilan AI. Percakapan disimpan di memori supaya riwayat bisa dicoba.
class AssistantFixtureDataSource implements AssistantRemoteDataSource {
  final _conversations = <String, (String title, DateTime updatedAt, List<ChatMessage> messages)>{};
  int _seq = 0;

  @override
  Future<ChatReply> sendMessage({
    required String? conversationId,
    required String requestId,
    required String content,
    AssetContext? context,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final about = context == null ? '' : ' tentang ${context.label}';
    final id = conversationId ?? 'fixture-conversation-${_seq++}';
    final now = DateTime.now();
    final reply = ChatMessage(
      id: 'reply-$requestId',
      role: ChatRole.assistant,
      createdAt: now,
      content:
          'Ini jawaban contoh$about. Endpoint AI mobile belum tersedia, '
          'jadi balasan ini tidak membaca data akunmu.',
    );
    final existing = _conversations[id];
    _conversations[id] = (
      existing?.$1 ?? (content.length > 60 ? content.substring(0, 60) : content),
      now,
      [
        ...?existing?.$3,
        ChatMessage(id: requestId, role: ChatRole.user, content: content, createdAt: now),
        reply,
      ],
    );
    return ChatReply(conversationId: id, message: reply);
  }

  @override
  Future<List<ConversationSummary>> listConversations() async => [
    for (final e in _conversations.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2)))
      ConversationSummary(id: e.key, title: e.value.$1, updatedAt: e.value.$2),
  ];

  @override
  Future<List<ChatMessage>> fetchMessages(String conversationId) async =>
      _conversations[conversationId]?.$3 ?? [];

  @override
  Future<void> renameConversation(String conversationId, String title) async {
    final c = _conversations[conversationId];
    if (c != null) _conversations[conversationId] = (title, c.$2, c.$3);
  }

  @override
  Future<void> deleteConversation(String conversationId) async => _conversations.remove(conversationId);
}
