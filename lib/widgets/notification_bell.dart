import 'package:flutter/material.dart';

import '../state/notification_scope.dart';
import 'app_ui.dart';
import 'unread_badge.dart';

/// Колокольчик в шапке раздела с числом непрочитанных уведомлений из
/// [NotificationScope]. Экраны показывают его, только когда scope есть.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bell = SquareIconButton(
      icon: Icons.notifications_none,
      onTap: onTap,
    );
    final unread = NotificationScope.maybeOf(context)?.unread;
    if (unread == null) return bell;
    return ListenableBuilder(
      listenable: unread,
      builder: (context, _) => CornerBadge(count: unread.count, child: bell),
    );
  }
}
