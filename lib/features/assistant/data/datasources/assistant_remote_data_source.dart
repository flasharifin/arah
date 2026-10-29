import 'package:arah/features/assistant/domain/entities/chat_message.dart';

/// Kontrak `POST /api/mobile/conversations/:id/messages` (usulan, belum ada di backend).
abstract interface class AssistantRemoteDataSource {
  Future<ChatReply> sendMessage({
    required String? conversationId,
    required String requestId,
    required String content,
    AssetContext? context,
  });
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
