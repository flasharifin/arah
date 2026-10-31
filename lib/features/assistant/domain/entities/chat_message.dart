import 'package:arah/core/error/failure.dart';
import 'package:equatable/equatable.dart';

enum ChatRole { user, assistant }

enum MessageStatus { sending, sent, failed }

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.failure,
  });

  /// Untuk pesan user, id ini juga `requestId` idempoten: retry memakai id yang sama.
  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final MessageStatus status;
  final Failure? failure;

  bool get isUser => role == ChatRole.user;

  ChatMessage withStatus(MessageStatus status, {Failure? failure}) =>
      ChatMessage(id: id, role: role, content: content, createdAt: createdAt, status: status, failure: failure);

  @override
  List<Object?> get props => [id, role, content, createdAt, status, failure];
}

/// Konteks aset opsional yang dilampirkan ke pertanyaan; bukan instruksi transaksi.
class AssetContext extends Equatable {
  const AssetContext({required this.symbol, required this.exchange});

  final String symbol;
  final String exchange;

  String get label => '$symbol · $exchange';

  @override
  List<Object?> get props => [symbol, exchange];
}

class ChatReply extends Equatable {
  const ChatReply({required this.conversationId, required this.message});

  final String conversationId;
  final ChatMessage message;

  @override
  List<Object?> get props => [conversationId, message];
}

/// Satu baris riwayat percakapan.
class ConversationSummary extends Equatable {
  const ConversationSummary({required this.id, required this.title, required this.updatedAt});

  final String id;
  final String title;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, title, updatedAt];
}
