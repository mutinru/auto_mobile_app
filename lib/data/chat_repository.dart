import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Источник данных чата: [ApiChatRepository] поверх Laravel API
/// (routes/api.php, /conversations) и [MockChatRepository] для тестов.
abstract class ChatRepository {
  /// Мой чат с поддержкой; сервер заводит его при первом вызове.
  Future<Conversation> openSupport();

  /// Страница до 50 сообщений, всегда по возрастанию id. Без курсора —
  /// последние; [beforeId] — история выше; [afterId] — новые (опрос).
  Future<List<ChatMessage>> fetchMessages(int conversationId, {int? afterId, int? beforeId});

  /// Текст и/или до 5 фото (пути к файлам).
  Future<ChatMessage> send(int conversationId, {String? body, List<String> photoPaths = const []});

  /// Прочитано до [messageId] включительно; назад сервер указатель не двигает.
  Future<void> markRead(int conversationId, int messageId);

  /// Заголовки для Image.network: фото чата приватные.
  Map<String, String> get imageHeaders;
}
