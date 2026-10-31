import 'package:arah/core/error/result.dart';
import 'package:arah/core/usecase/usecase.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';
import 'package:arah/features/assistant/domain/repositories/assistant_repository.dart';

class ListConversations implements UseCase<List<ConversationSummary>, NoParams> {
  const ListConversations(this._repository);
  final AssistantRepository _repository;

  @override
  Future<Result<List<ConversationSummary>>> call(NoParams params) => _repository.listConversations();
}

/// Parameter: id percakapan.
class LoadConversation implements UseCase<List<ChatMessage>, String> {
  const LoadConversation(this._repository);
  final AssistantRepository _repository;

  @override
  Future<Result<List<ChatMessage>>> call(String conversationId) => _repository.loadConversation(conversationId);
}

class RenameConversation implements UseCase<void, ({String id, String title})> {
  const RenameConversation(this._repository);
  final AssistantRepository _repository;

  @override
  Future<Result<void>> call(({String id, String title}) params) =>
      _repository.renameConversation(params.id, params.title);
}

/// Parameter: id percakapan.
class DeleteConversation implements UseCase<void, String> {
  const DeleteConversation(this._repository);
  final AssistantRepository _repository;

  @override
  Future<Result<void>> call(String conversationId) => _repository.deleteConversation(conversationId);
}
