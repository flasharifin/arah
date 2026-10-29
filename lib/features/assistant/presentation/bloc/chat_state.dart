part of 'chat_bloc.dart';

class ChatState extends Equatable {
  const ChatState({this.messages = const [], this.conversationId, this.context, this.prefill});

  final List<ChatMessage> messages;
  final String? conversationId;
  final AssetContext? context;

  /// Teks yang perlu dimasukkan ke composer (dari konteks aset atau edit pesan gagal).
  final String? prefill;

  bool get isAwaitingReply => messages.any((m) => m.status == MessageStatus.sending);

  ChatState replace(ChatMessage message) =>
      copyWith(messages: [for (final m in messages) m.id == message.id ? message : m]);

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? conversationId,
    AssetContext? Function()? context,
    String? Function()? prefill,
  }) => ChatState(
    messages: messages ?? this.messages,
    conversationId: conversationId ?? this.conversationId,
    context: context != null ? context() : this.context,
    prefill: prefill != null ? prefill() : this.prefill,
  );

  @override
  List<Object?> get props => [messages, conversationId, context, prefill];
}
