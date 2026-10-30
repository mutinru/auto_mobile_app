import '../models/app_notification.dart';

/// Страница ленты: курсор следующей (null — дальше пусто) и число
/// непрочитанных на сервере.
class NotificationPage {
  const NotificationPage({required this.items, this.nextCursor, this.unreadCount = 0});

  final List<AppNotification> items;
  final String? nextCursor;
  final int unreadCount;
}

/// Источник ленты уведомлений: [ApiNotificationRepository] поверх Laravel
/// API (routes/api.php, /notifications) и [MockNotificationRepository] для
/// тестов.
abstract class NotificationRepository {
  /// Свежие сверху, по 20. Без курсора — первая страница.
  Future<NotificationPage> fetchPage({String? cursor});

  /// Непрочитанные — для бейджа колокольчика.
  Future<int> fetchUnreadCount();

  /// Отметить одно; сервер возвращает его с read_at.
  Future<AppNotification> markRead(String id);

  /// Отметить все; возвращает новое число непрочитанных (0).
  Future<int> markAllRead();
}
