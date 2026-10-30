import '../models/app_notification.dart';
import 'api_client.dart';
import 'notification_repository.dart';

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._client);

  final ApiClient _client;

  @override
  Future<NotificationPage> fetchPage({String? cursor}) async {
    final query = cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}';
    final json = await _client.get('/notifications$query');
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return NotificationPage(
      items: [
        for (final n in json['data'] as List) AppNotification.fromJson(n as Map<String, dynamic>),
      ],
      nextCursor: meta['next_cursor'] as String?,
      unreadCount: meta['unread_count'] as int? ?? 0,
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    final json = await _client.get('/notifications/unread-count');
    return json['unread_count'] as int? ?? 0;
  }

  @override
  Future<AppNotification> markRead(String id) async {
    final json = await _client.post('/notifications/$id/read');
    return AppNotification.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> markAllRead() async {
    final json = await _client.post('/notifications/read-all');
    return json['unread_count'] as int? ?? 0;
  }
}
