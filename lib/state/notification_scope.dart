import 'package:flutter/widgets.dart';

import '../data/api_client.dart';
import '../data/api_notification_repository.dart';
import '../data/auth_service.dart';
import '../data/notification_repository.dart';
import 'notification_unread.dart';

/// Лента уведомлений для колокольчиков в шапках разделов. Стоит в
/// MaterialApp.builder рядом с SupportChatScope. Нет scope (виджет-тесты
/// отдельных экранов) — нет и колокольчика.
class NotificationScope extends InheritedWidget {
  NotificationScope({
    super.key,
    required this.auth,
    NotificationRepository Function()? repository,
    this.unread,
    required super.child,
  }) : repository = repository ?? (() => ApiNotificationRepository(ApiClient(auth)));

  final AuthService auth;

  /// Непрочитанные для бейджа; null — колокольчик без бейджа.
  final NotificationUnread? unread;

  /// Новый репозиторий на каждое открытие ленты.
  final NotificationRepository Function() repository;

  static NotificationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotificationScope>();

  @override
  // фабрика по умолчанию — новое замыкание на каждой сборке, сравнивать её бессмысленно
  bool updateShouldNotify(NotificationScope oldWidget) =>
      auth != oldWidget.auth || unread != oldWidget.unread;
}
