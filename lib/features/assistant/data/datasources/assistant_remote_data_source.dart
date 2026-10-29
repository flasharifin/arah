import 'package:arah/core/network/api_client.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';

abstract interface class AssistantRemoteDataSource {
  Future<ChatReply> sendMessage({
    required String? conversationId,
    required String requestId,
    required String content,
    AssetContext? context,
  });
}

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
    final m = data['message'] as Map<String, dynamic>;
    return ChatReply(
      conversationId: data['conversationId'] as String,
      message: ChatMessage(
        id: m['id'] as String,
        role: ChatRole.assistant,
        content: m['content'] as String,
        createdAt: DateTime.parse(m['createdAt'] as String),
      ),
    );
  }
}

/// Balasan ilustrasi; bukan hasil pemanggilan AI.
class AssistantFixtureDataSource implements AssistantRemoteDataSource {
  @override
  Future<ChatReply> sendMessage({
    required String? conversationId,
    required String requestId,
    required String content,
    AssetContext? context,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final about = context == null ? '' : ' tentang ${context.label}';
    return ChatReply(
      conversationId: conversationId ?? 'fixture-conversation',
      message: ChatMessage(
        id: 'reply-$requestId',
        role: ChatRole.assistant,
        createdAt: DateTime.now(),
        content:
            'Ini jawaban contoh$about. Endpoint AI mobile belum tersedia, '
            'jadi balasan ini tidak membaca data akunmu.',
      ),
    );
  }
}
