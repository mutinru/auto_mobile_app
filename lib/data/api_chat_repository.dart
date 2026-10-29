import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../models/conversation_type.dart';
import 'api_client.dart';
import 'chat_repository.dart';

class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._client);

  final ApiClient _client;

  @override
  Future<Conversation> openSupport() async {
    final json = await _client.post('/support/conversation');
    return Conversation.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<ChatMessage>> fetchMessages(int conversationId, {int? afterId, int? beforeId}) async {
    final query = [
      if (afterId != null) 'after_id=$afterId',
      if (beforeId != null) 'before_id=$beforeId',
    ].join('&');
    final json = await _client.get(
      '/conversations/$conversationId/messages${query.isEmpty ? '' : '?$query'}',
    );
    return [
      for (final m in json['data'] as List) ChatMessage.fromJson(m as Map<String, dynamic>),
    ];
  }

  @override
  Future<ChatMessage> send(int conversationId, {String? body, List<String> photoPaths = const []}) async {
    // multipart идёт мимо ApiClient — тот умеет только JSON
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/conversations/$conversationId/messages'),
    )
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer ${_client.token}';
    if (body != null && body.isNotEmpty) request.fields['body'] = body;
    for (final path in photoPaths) {
      request.files.add(await http.MultipartFile.fromPath('photos[]', path));
    }

    final streamed = await request.send();
    final text = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw _client.failure(streamed.statusCode, text);
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    return ChatMessage.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> fetchSupportUnread() async {
    // GET, а не POST /support/conversation — тот заводит разговор
    final json = await _client.get('/conversations');
    var total = 0;
    for (final c in json['data'] as List) {
      final conversation = Conversation.fromJson(c as Map<String, dynamic>);
      if (conversation.type == ConversationType.support) total += conversation.unreadCount;
    }
    return total;
  }

  @override
  Future<void> markRead(int conversationId, int messageId) =>
      _client.post('/conversations/$conversationId/read', {'message_id': messageId});

  @override
  Map<String, String> get imageHeaders => {
        if (_client.token != null) 'Authorization': 'Bearer ${_client.token}',
      };
}
