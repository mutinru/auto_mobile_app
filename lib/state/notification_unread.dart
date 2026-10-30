import '../data/notification_repository.dart';
import 'polled_unread.dart';

/// Непрочитанные уведомления — для бейджа колокольчика в шапках разделов.
class NotificationUnread extends PolledUnread {
  NotificationUnread(
    super.auth,
    this._repository, {
    super.pollInterval,
  });

  final NotificationRepository _repository;

  @override
  Future<int> fetchCount() => _repository.fetchUnreadCount();
}
