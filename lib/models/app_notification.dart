import 'notification_type.dart';
import 'order_kind.dart';

/// Уведомление ленты (NotificationResource на бекенде). Прочитанность —
/// только с сервера: локально [readAt] не выставляем.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.orderId,
    this.orderKind = OrderKind.selection,
    this.viewerIsCustomer = true,
    this.readAt,
  });

  /// uuid, а не число.
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final int? orderId;
  final OrderKind orderKind;

  /// Кем смотрящий приходится заказу — от этого зависит экран заказа.
  final bool viewerIsCustomer;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  /// Открывается ли заказ по тапу. Отклонённый исполнитель заказ уже не
  /// видит (сервер ответит 403), поэтому его уведомление только читается.
  bool get opensOrder =>
      orderId != null && type != NotificationType.responseRejected;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final type = notificationTypeFromApi(json['type'] as String?);
    final role = json['viewer_role'] as String?;
    return AppNotification(
      id: json['id'] as String,
      type: type,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      orderId: json['order_id'] as int?,
      orderKind: orderKindFromApi(json['order_kind'] as String?),
      viewerIsCustomer: role == null ? type.defaultViewerIsCustomer : role == 'customer',
      readAt: _date(json['read_at']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value).toLocal() : null;
}
