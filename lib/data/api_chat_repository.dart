import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/conversation_type.dart';
import 'api_client.dart';
import 'chat_repository.dart';
import 'json_list.dart';

class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._client);

  final ApiClient _client;

  @override
  Future<Conversation> openSupport() async {
    final json = await _client.post('/support/conversation');
    return Conversation.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<ChatMessage>> fetchMessages(
    int conversationId, {
    int? afterId,
    int? beforeId,
  }) async {
    final query = [
      if (afterId != null) 'after_id=$afterId',
      if (beforeId != null) 'before_id=$beforeId',
    ].join('&');
    final json = await _client.get(
      '/conversations/$conversationId/messages${query.isEmpty ? '' : '?$query'}',
    );
    return parseList(json['data'], ChatMessage.fromJson, what: 'сообщение');
  }

  @override
  Future<ChatMessage> send(
    int conversationId, {
    String? body,
    List<String> photoPaths = const [],
  }) async {
    final json = await _client.multipart(
      '/conversations/$conversationId/messages',
      fields: {'body': ?(body == null || body.isEmpty ? null : body)},
      files: [
        for (final path in photoPaths)
          await http.MultipartFile.fromPath('photos[]', path),
      ],
    );
    return ChatMessage.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> fetchSupportUnread() async {
    // GET, а не POST /support/conversation — тот заводит разговор
    final json = await _client.get('/conversations');
    var total = 0;
    for (final conversation in parseList(
      json['data'],
      Conversation.fromJson,
      what: 'разговор',
    )) {
      if (conversation.type == ConversationType.support) {
        total += conversation.unreadCount;
      }
    }
    return total;
  }

  @override
  Future<void> markRead(int conversationId, int messageId) => _client.post(
    '/conversations/$conversationId/read',
    {'message_id': messageId},
  );

  @override
  Map<String, String> get imageHeaders => {
    if (_client.token != null) 'Authorization': 'Bearer ${_client.token}',
  };
}
