import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';
import 'package:arah/features/assistant/domain/repositories/assistant_repository.dart';

class SendChatMessageParams {
  const SendChatMessageParams({
    required this.conversationId,
    required this.requestId,
    required this.content,
    this.context,
  });

  final String? conversationId;
  final String requestId;
  final String content;
  final AssetContext? context;
}

class SendChatMessage implements UseCase<ChatReply, SendChatMessageParams> {
  const SendChatMessage(this._repository);
  final AssistantRepository _repository;

  @override
  Future<Result<ChatReply>> call(SendChatMessageParams params) => _repository.sendMessage(
    conversationId: params.conversationId,
    requestId: params.requestId,
    content: params.content.trim(),
    context: params.context,
  );
}
