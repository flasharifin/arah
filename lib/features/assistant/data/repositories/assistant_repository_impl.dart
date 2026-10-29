import 'package:arah/core/error/guard.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/assistant/data/datasources/assistant_remote_data_source.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';
import 'package:arah/features/assistant/domain/repositories/assistant_repository.dart';

class AssistantRepositoryImpl implements AssistantRepository {
  const AssistantRepositoryImpl(this._remote);
  final AssistantRemoteDataSource _remote;

  @override
  Future<Result<ChatReply>> sendMessage({
    required String? conversationId,
    required String requestId,
    required String content,
    AssetContext? context,
  }) => guard(
    () => _remote.sendMessage(
      conversationId: conversationId,
      requestId: requestId,
      content: content,
      context: context,
    ),
  );
}
