import 'chat_message.dart';
import 'conversation_type.dart';

/// Разговор (ConversationResource на бекенде). Число непрочитанных
/// считает сервер — локально не пересчитываем.
class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.title,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final int id;
  final ConversationType type;
  final String title;
  final ChatMessage? lastMessage;
  final int unreadCount;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as int,
        type: conversationTypeFromApi(json['type'] as String?),
        title: json['title'] as String? ?? 'Поддержка',
        lastMessage: json['last_message'] == null
            ? null
            : ChatMessage.fromJson(json['last_message'] as Map<String, dynamic>),
        unreadCount: json['unread_count'] as int? ?? 0,
      );
}
