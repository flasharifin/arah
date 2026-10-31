import 'package:arah/features/assistant/domain/entities/chat_message.dart';
import 'package:arah/features/assistant/domain/usecases/send_chat_message.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({required SendChatMessage sendMessage, String Function()? newId, DateTime Function()? now})
    : _sendMessage = sendMessage,
      _newId = newId ?? _defaultId,
      _now = now ?? DateTime.now,
      super(const ChatState()) {
    on<ChatContextAttached>((e, emit) => emit(state.copyWith(context: () => e.context, prefill: () => e.prefill)));
    on<ChatPrefillRequested>((e, emit) => emit(state.copyWith(prefill: () => e.text)));
    on<ChatContextCleared>((e, emit) => emit(state.copyWith(context: () => null)));
    on<ChatMessageSent>(_onSent);
    on<ChatRetryRequested>(_onRetry);
    on<ChatFailedMessageEdited>(_onEdit);
    on<ChatResetRequested>((e, emit) => emit(const ChatState()));
    // Percakapan lama dari riwayat: pesan sudah dimuat halaman riwayat, lanjut chat di percakapan itu.
    on<ChatConversationLoaded>((e, emit) => emit(ChatState(conversationId: e.conversationId, messages: e.messages)));
  }

  final SendChatMessage _sendMessage;
  final String Function() _newId;
  final DateTime Function() _now;

  static int _seq = 0;
  static String _defaultId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  Future<void> _onSent(ChatMessageSent event, Emitter<ChatState> emit) async {
    final content = event.content.trim();
    if (content.isEmpty || state.isAwaitingReply) return;
    final message = ChatMessage(
      id: _newId(),
      role: ChatRole.user,
      content: content,
      createdAt: _now(),
      status: MessageStatus.sending,
    );
    emit(state.copyWith(messages: [...state.messages, message], prefill: () => null));
    await _deliver(message, emit);
  }

  /// Mengirim ulang pesan yang sama (id = requestId sama), tidak menambah pesan baru.
  Future<void> _onRetry(ChatRetryRequested event, Emitter<ChatState> emit) async {
    final message = state.messages.where((m) => m.id == event.messageId).firstOrNull;
    if (message == null || message.status != MessageStatus.failed) return;
    emit(state.replace(message.withStatus(MessageStatus.sending)));
    await _deliver(message, emit);
  }

  void _onEdit(ChatFailedMessageEdited event, Emitter<ChatState> emit) {
    final message = state.messages.where((m) => m.id == event.messageId).firstOrNull;
    if (message == null || message.status != MessageStatus.failed) return;
    emit(
      state.copyWith(
        messages: state.messages.where((m) => m.id != message.id).toList(),
        prefill: () => message.content,
      ),
    );
  }

  Future<void> _deliver(ChatMessage message, Emitter<ChatState> emit) async {
    final result = await _sendMessage(
      SendChatMessageParams(
        conversationId: state.conversationId,
        requestId: message.id,
        content: message.content,
        context: state.context,
      ),
    );
    result.fold((failure) => emit(state.replace(message.withStatus(MessageStatus.failed, failure: failure))), (reply) {
      final sent = state.replace(message.withStatus(MessageStatus.sent));
      emit(
        sent.copyWith(
          messages: [...sent.messages, reply.message],
          conversationId: reply.conversationId,
          context: () => null,
        ),
      );
    });
  }
}
