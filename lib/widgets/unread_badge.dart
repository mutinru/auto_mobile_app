import 'package:flutter/material.dart';

import '../state/support_chat_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// .badge из tab-bar-navigation.html — число непрочитанных. 0 — ничего.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge(this.count, {super.key, this.borderColor});

  final int count;

  /// Обводка цветом фона под бейджем — отделяет его от иконки.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.statusInfo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor ?? c.bg0, width: 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontFamily: AppTheme.monoFamily,
          fontSize: 9.5,
          height: 1,
          fontWeight: FontWeight.w600,
          color: c.infoInk,
        ),
      ),
    );
  }
}

/// Непрочитанные в чате поддержки из [SupportChatScope]. Без scope или
/// счётчика (виджет-тесты отдельных экранов) — всегда 0.
class SupportUnreadBuilder extends StatelessWidget {
  const SupportUnreadBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, int count) builder;

  @override
  Widget build(BuildContext context) {
    final unread = SupportChatScope.maybeOf(context)?.unread;
    if (unread == null) return builder(context, 0);
    return ListenableBuilder(
      listenable: unread,
      builder: (context, _) => builder(context, unread.count),
    );
  }
}

/// Бейдж непрочитанных поддержки в правом верхнем углу [child] — для
/// любого входа в чат (пилюля «Поддержка», иконка профиля).
class SupportUnreadBadge extends StatelessWidget {
  const SupportUnreadBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SupportUnreadBuilder(
      builder: (context, count) => Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (count > 0)
            Positioned(top: -6, right: -6, child: UnreadBadge(count)),
        ],
      ),
    );
  }
}
