import 'notification_type.dart';
import 'order_kind.dart';

/// Куда ведёт тап по пушу. Разбирается из `data` FCM-сообщения: у пушей о
/// заказе это те же поля, что у записи ленты (OrderNotification::toFcm на
/// бекенде), у чата — `type: chat_message`. Все значения в data — строки.
sealed class PushTarget {
  const PushTarget();

  /// null — пуш непонятного вида: тап просто откроет приложение.
  static PushTarget? fromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == 'chat_message') {
      return data['conversation_type'] == 'support' ? const SupportChatTarget() : null;
    }

    final orderId = int.tryParse('${data['order_id']}');
    final notificationType = notificationTypeFromApi(type);
    if (orderId == null || notificationType == NotificationType.unknown) return null;
    final role = data['viewer_role'] as String?;
    return OrderTarget(
      type: notificationType,
      orderId: orderId,
      orderKind: orderKindFromApi(data['order_kind'] as String?),
      viewerIsCustomer: role == null ? notificationType.defaultViewerIsCustomer : role == 'customer',
      notificationId: data['notification_id'] as String?,
    );
  }
}

/// Пуш о заказе — открыть заказ и отметить запись ленты прочитанной.
class OrderTarget extends PushTarget {
  const OrderTarget({
    required this.type,
    required this.orderId,
    required this.orderKind,
    required this.viewerIsCustomer,
    this.notificationId,
  });

  final NotificationType type;
  final int orderId;
  final OrderKind orderKind;
  final bool viewerIsCustomer;

  /// id записи ленты (тот же, что в GET /notifications).
  final String? notificationId;

  /// Отклонённый исполнитель заказ уже не видит — ведём в ленту.
  bool get opensOrder => type != NotificationType.responseRejected;
}

/// Ответ поддержки — открыть чат поддержки.
class SupportChatTarget extends PushTarget {
  const SupportChatTarget();
}
