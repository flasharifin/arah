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
}
