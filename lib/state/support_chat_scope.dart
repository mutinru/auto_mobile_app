import 'package:flutter/widgets.dart';

import '../data/api_chat_repository.dart';
import '../data/api_client.dart';
import '../data/auth_service.dart';
import '../data/chat_repository.dart';

/// Доступ к чату поддержки из любого маршрута: шторку открывают экраны,
/// у которых нет AuthService (вопрос о намерении, FAQ, оплата). Стоит в
/// MaterialApp.builder — выше Navigator.
class SupportChatScope extends InheritedWidget {
  SupportChatScope({
    super.key,
    required this.auth,
    ChatRepository Function()? repository,
    required super.child,
  }) : repository = repository ?? (() => ApiChatRepository(ApiClient(auth)));

  final AuthService auth;

  /// Новый репозиторий на каждое открытие чата.
  final ChatRepository Function() repository;

  /// null — scope нет (виджет-тесты отдельных экранов): чат недоступен,
  /// шторка ведёт в Telegram.
  static SupportChatScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SupportChatScope>();

  @override
  // фабрика по умолчанию — новое замыкание на каждой сборке, сравнивать её бессмысленно
  bool updateShouldNotify(SupportChatScope oldWidget) => auth != oldWidget.auth;
}
