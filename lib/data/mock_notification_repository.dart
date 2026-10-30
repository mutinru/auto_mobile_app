import '../models/app_notification.dart';
import 'api_exception.dart';
import 'notification_repository.dart';

/// Лента в памяти для виджет-тестов. Своя фикстура — с MockOrderRepository
/// не пересекается. Ведёт себя как сервер: свежие сверху, курсор — индекс.
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository({List<AppNotification>? items, this.pageSize = 20})
      : _items = [...?items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final List<AppNotification> _items;
  final int pageSize;

  /// fetchPage() падает — экран ошибки.
  bool failPage = false;

  /// fetchUnreadCount() падает — нет сети.
  bool failUnread = false;

  /// id, отмеченные через [markRead], по порядку.
  final List<String> readCalls = [];

  int get unreadCount => _items.where((n) => !n.isRead).length;

  @override
  Future<NotificationPage> fetchPage({String? cursor}) async {
    if (failPage) throw ApiException(500, '');
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, _items.length);
    return NotificationPage(
      items: _items.sublist(start, end),
      nextCursor: end < _items.length ? '$end' : null,
      unreadCount: unreadCount,
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    if (failUnread) throw Exception('no network');
    return unreadCount;
  }

  @override
  Future<AppNotification> markRead(String id) async {
    readCalls.add(id);
    final i = _items.indexWhere((n) => n.id == id);
    if (i < 0) throw ApiException(404, '');
    return _items[i] = _read(_items[i]);
  }

  @override
  Future<int> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _read(_items[i]);
    }
    return 0;
  }

  /// Новое уведомление — придёт со следующим опросом.
  void add(AppNotification notification) => _items.insert(0, notification);

  static AppNotification _read(AppNotification n) => n.isRead
      ? n
      : AppNotification(
          id: n.id,
          type: n.type,
          title: n.title,
          body: n.body,
          createdAt: n.createdAt,
          orderId: n.orderId,
          orderKind: n.orderKind,
          viewerIsCustomer: n.viewerIsCustomer,
          readAt: DateTime.now(),
        );
}
