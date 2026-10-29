import 'package:arah/core/error/failure.dart';
import 'package:arah/core/error/result.dart';
import 'package:arah/features/assistant/domain/entities/chat_message.dart';
import 'package:arah/features/assistant/domain/repositories/assistant_repository.dart';
import 'package:arah/features/assistant/domain/usecases/send_chat_message.dart';
import 'package:arah/features/assistant/presentation/bloc/chat_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gagal pada panggilan pertama, sukses setelahnya; mencatat requestId yang dikirim.
class _FlakyRepository implements AssistantRepository {
  final requestIds = <String>[];

  @override
  Future<Result<ChatReply>> sendMessage({
    required String? conversationId,
    required String requestId,
    required String content,
    AssetContext? context,
  }) async {
    requestIds.add(requestId);
    if (requestIds.length == 1) {
      return const Error(Failure(FailureCode.timeout, 'Server terlalu lama merespons.'));
    }
    return Success(
      ChatReply(
        conversationId: 'c1',
        message: ChatMessage(id: 'r1', role: ChatRole.assistant, content: 'ok', createdAt: DateTime(2026)),
      ),
    );
  }

  @override
  Future<Result<List<ConversationSummary>>> listConversations() => throw UnimplementedError();
  @override
  Future<Result<List<ChatMessage>>> loadConversation(String conversationId) => throw UnimplementedError();
  @override
  Future<Result<void>> renameConversation(String conversationId, String title) => throw UnimplementedError();
  @override
  Future<Result<void>> deleteConversation(String conversationId) => throw UnimplementedError();
}

void main() {
  test('retry memakai requestId yang sama dan tidak menduplikasi pesan user', () async {
    final repo = _FlakyRepository();
    var seq = 0;
    final bloc = ChatBloc(sendMessage: SendChatMessage(repo), newId: () => 'm${seq++}');

    bloc.add(const ChatMessageSent('Review BBCA'));
    await bloc.stream.firstWhere((s) => s.messages.single.status == MessageStatus.failed);

    bloc.add(const ChatRetryRequested('m0'));
    final state = await bloc.stream.firstWhere((s) => s.messages.length == 2);

    expect(repo.requestIds, ['m0', 'm0']);
    expect(state.messages.where((m) => m.isUser), hasLength(1));
    expect(state.messages.first.status, MessageStatus.sent);
    expect(state.conversationId, 'c1');
    await bloc.close();
  });

  test('pesan kosong diabaikan', () async {
    final repo = _FlakyRepository();
    final bloc = ChatBloc(sendMessage: SendChatMessage(repo))..add(const ChatMessageSent('   '));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.messages, isEmpty);
    expect(repo.requestIds, isEmpty);
    await bloc.close();
  });
}
