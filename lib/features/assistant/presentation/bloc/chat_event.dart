part of 'chat_bloc.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// Dari layar aset: lampirkan konteks dan isi composer. Pengguna tetap yang menekan Kirim.
final class ChatContextAttached extends ChatEvent {
  const ChatContextAttached(this.context, {this.prefill});

  final AssetContext context;
  final String? prefill;

  @override
  List<Object?> get props => [context, prefill];
}

/// Isi composer dari contoh pertanyaan.
final class ChatPrefillRequested extends ChatEvent {
  const ChatPrefillRequested(this.text);
  final String text;

  @override
  List<Object?> get props => [text];
}

final class ChatContextCleared extends ChatEvent {
  const ChatContextCleared();
}

final class ChatMessageSent extends ChatEvent {
  const ChatMessageSent(this.content);
  final String content;

  @override
  List<Object?> get props => [content];
}

final class ChatRetryRequested extends ChatEvent {
  const ChatRetryRequested(this.messageId);
  final String messageId;

  @override
  List<Object?> get props => [messageId];
}

/// Pesan gagal dikembalikan ke composer untuk diedit.
final class ChatFailedMessageEdited extends ChatEvent {
  const ChatFailedMessageEdited(this.messageId);
  final String messageId;

  @override
  List<Object?> get props => [messageId];
}

final class ChatResetRequested extends ChatEvent {
  const ChatResetRequested();
}
