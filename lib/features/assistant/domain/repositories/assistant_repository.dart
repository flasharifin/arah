import 'package:arah/core/error/result.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';

abstract interface class AssistantRepository {
  /// [conversationId] `null` membuat percakapan baru.
  Future<Result<ChatReply>> sendMessage({
    required String? conversationId,
    required String requestId,
    required String content,
    AssetContext? context,
  });

  Future<Result<List<ConversationSummary>>> listConversations();
  Future<Result<List<ChatMessage>>> loadConversation(String conversationId);
  Future<Result<void>> renameConversation(String conversationId, String title);
  Future<Result<void>> deleteConversation(String conversationId);
}
