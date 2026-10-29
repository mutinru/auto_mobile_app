import '../models/chat_message.dart';
import '../models/chat_role.dart';
import '../models/conversation.dart';
import '../models/conversation_type.dart';
import 'api_exception.dart';
import 'chat_repository.dart';

/// Чат в памяти для виджет-тестов. Своя фикстура — с MockOrderRepository
/// не пересекается. Ответ оператора тест имитирует через [simulateReply].
class MockChatRepository implements ChatRepository {
  MockChatRepository({List<ChatMessage>? messages, this.failOpen = false, this.supportUnread = 0})
      : _messages = [...?messages];

  /// Что вернёт [fetchSupportUnread]; [markRead] обнуляет — как сервер.
  int supportUnread;

  /// fetchSupportUnread() падает — нет сети.
  bool failUnread = false;

  final List<ChatMessage> _messages;

  /// openSupport() падает — проверка экрана ошибки.
  bool failOpen;

  int? lastReadId;
  int _nextId = 1000;

  static const conversationId = 1;

  @override
  Future<Conversation> openSupport() async {
    if (failOpen) throw ApiException(500, '');
    return const Conversation(id: conversationId, type: ConversationType.support, title: 'Поддержка');
  }

  @override
  Future<List<ChatMessage>> fetchMessages(int conversationId, {int? afterId, int? beforeId}) async {
    final sorted = [..._messages]..sort((a, b) => a.id.compareTo(b.id));
    if (afterId != null) {
      return sorted.where((m) => m.id > afterId).take(50).toList();
    }
    final older = beforeId == null ? sorted : sorted.where((m) => m.id < beforeId).toList();
    return older.length > 50 ? older.sublist(older.length - 50) : older;
  }

  @override
  Future<ChatMessage> send(int conversationId, {String? body, List<String> photoPaths = const []}) async {
    final message = ChatMessage(id: _nextId++, body: body, isMine: true, createdAt: DateTime.now());
    _messages.add(message);
    return message;
  }

  @override
  Future<int> fetchSupportUnread() async {
    if (failUnread) throw Exception('no network');
    return supportUnread;
  }

  @override
  Future<void> markRead(int conversationId, int messageId) async {
    lastReadId = messageId;
    supportUnread = 0;
  }

  @override
  Map<String, String> get imageHeaders => const {};

  /// Оператор ответил — придёт со следующим опросом.
  void simulateReply(String text) {
    _messages.add(ChatMessage(
      id: _nextId++,
      body: text,
      senderRole: ChatRole.support,
      senderName: 'Поддержка',
      createdAt: DateTime.now(),
    ));
  }
}
