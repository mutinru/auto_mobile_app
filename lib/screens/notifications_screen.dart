import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/notification_repository.dart';
import '../models/app_notification.dart';
import '../models/notification_type.dart';
import '../models/order_kind.dart';
import '../state/notification_scope.dart';
import '../state/notification_store.dart';
import '../state/notification_unread.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/ru_date.dart';
import '../util/ru_plural.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import 'order_routes.dart';

/// Открыть ленту колокольчиком из шапки раздела. Репозиторий берём из
/// [NotificationScope] до маршрута, а не в builder: при смене темы builder
/// зовётся заново. По возврату бейдж переспрашивает сервер.
Future<void> openNotifications(
  BuildContext context, {
  required OrderStore store,
  AuthService? auth,
}) async {
  final scope = NotificationScope.maybeOf(context);
  if (scope == null) return;
  final repository = scope.repository();
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => NotificationsScreen(
        store: store,
        auth: auth,
        repository: repository,
        unread: scope.unread,
      ),
    ),
  );
  scope.unread?.refresh();
}

/// Лента уведомлений о заказах (GET /notifications). Макета нет — карточки
/// собраны из тех же кирпичей, что отзывы. Прочитано — по тапу или кнопкой
/// «Прочитать все»; тап ещё и открывает заказ.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.store,
    required this.repository,
    this.auth,
    this.unread,
  });

  /// Стор раздела — на нём открываются экраны заказов.
  final OrderStore store;
  final NotificationRepository repository;
  final AuthService? auth;
  final NotificationUnread? unread;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // стор живёт в State: экран переживает смену темы вместе с ним
  late final _feed = NotificationStore(widget.repository, unread: widget.unread);

  @override
  void initState() {
    super.initState();
    _feed.loadMore();
  }

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  Future<void> _open(AppNotification notification) async {
    try {
      await _feed.markRead(notification);
    } catch (e) {
      if (mounted) showApiError(context, e);
      return;
    }
    if (!notification.opensOrder || !mounted) return;
    await openOrderScreen(
      context,
      store: widget.store,
      auth: widget.auth,
      orderId: notification.orderId!,
      isInspection: notification.orderKind.isInspection,
      asExecutor: !notification.viewerIsCustomer,
    );
  }

  Future<void> _readAll() async {
    try {
      await _feed.markAllRead();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _feed,
          builder: (context, _) {
            final unread = _feed.unreadCount;
            return Column(
              children: [
                DetailHead(
                  title: 'Уведомления',
                  eyebrow: unread > 0
                      ? counted(unread, 'новое', 'новых', 'новых')
                      : null,
                  onBack: () => Navigator.of(context).pop(),
                  // CtaGhost растянут на всю ширину — в шапку нужна компактная
                  trailing: unread > 0
                      ? TextButton(
                          onPressed: _readAll,
                          child: Text('Прочитать все', style: context.text.ctaGhost),
                        )
                      : null,
                ),
                Expanded(child: _body()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body() {
    final items = _feed.items;
    final error = _feed.error;

    if (error != null && items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Не удалось загрузить уведомления',
              style: TextStyle(fontSize: 14, color: context.colors.text1),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: context.colors.text3),
            ),
            const SizedBox(height: 10),
            CtaGhost(label: 'Повторить', onPressed: _feed.refresh),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return _feed.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Text(
                'Пока ничего нет',
                style: TextStyle(fontSize: 13, color: context.colors.text2),
              ),
            );
    }

    // строки ленты: заголовок дня перед первым уведомлением этого дня
    final rows = <Widget>[];
    String? day;
    for (final n in items) {
      final label = chatDay(n.createdAt);
      if (label != day) {
        if (day != null) rows.add(const SizedBox(height: 6));
        rows.add(SectionHead(label));
        day = label;
      }
      rows.add(_NotificationCard(notification: n, onTap: () => _open(n)));
    }

    return RefreshIndicator(
      onRefresh: _feed.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
        children: [
          ...rows,
          if (_feed.hasMore)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: error != null
                    ? CtaGhost(label: 'Повторить', onPressed: _feed.loadMore)
                    : _LoadMore(
                        // новый ключ на каждую страницу — иначе State
                        // переиспользуется и initState больше не позовётся
                        key: ValueKey(items.length),
                        onShown: _feed.loadMore,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Спиннер в конце ленты; список строит его, только когда до конца
/// докрутили, — тогда и просим следующую страницу. По прокрутке нельзя:
/// короткая первая страница не прокручивается, и спиннер висел бы вечно.
class _LoadMore extends StatefulWidget {
  const _LoadMore({super.key, required this.onShown});

  final VoidCallback onShown;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  void initState() {
    super.initState();
    // не во время build: стор уведомит слушателей
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShown();
    });
  }

  @override
  Widget build(BuildContext context) => const CircularProgressIndicator();
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = notification;
    final tone = _tone(c, n.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: n.isRead ? c.line : c.statusInfo.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon(n.type), size: 17, color: tone),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w600,
                                color: n.isRead ? c.text2 : c.text1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!n.isRead) ...[
                            Container(
                              key: const ValueKey('unread-dot'),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: c.statusInfo,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            hhmm(n.createdAt),
                            style: TextStyle(
                              fontFamily: AppTheme.monoFamily,
                              fontSize: 11,
                              color: c.text3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.body,
                        style: TextStyle(fontSize: 12.5, height: 1.4, color: c.text2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _icon(NotificationType type) => switch (type) {
        NotificationType.responseReceived => Icons.person_add_alt,
        NotificationType.executorReleased => Icons.person_off_outlined,
        NotificationType.reportReady => Icons.description_outlined,
        NotificationType.reportOpened => Icons.lock_open,
        NotificationType.executorAssigned => Icons.check_circle_outline,
        NotificationType.responseRejected => Icons.do_not_disturb_alt,
        NotificationType.deadlineSoon => Icons.timer_outlined,
        NotificationType.paymentSent => Icons.payments_outlined,
        NotificationType.orderCompleted => Icons.flag_outlined,
        NotificationType.orderCancelled => Icons.cancel_outlined,
        NotificationType.reviewReceived => Icons.star_outline,
        NotificationType.disputeOpened => Icons.gavel,
        NotificationType.disputeResolved => Icons.handshake_outlined,
        NotificationType.unknown => Icons.notifications_none,
      };

  /// Тон иконки: хорошее — done, ждёт действия — progress, плохое — defect.
  static Color _tone(AppColors c, NotificationType type) => switch (type) {
        NotificationType.executorAssigned ||
        NotificationType.reportOpened ||
        NotificationType.orderCompleted ||
        NotificationType.disputeResolved =>
          c.statusDone,
        NotificationType.executorReleased ||
        NotificationType.deadlineSoon ||
        NotificationType.paymentSent =>
          c.statusProgress,
        NotificationType.orderCancelled || NotificationType.disputeOpened => c.statusDefect,
        NotificationType.responseRejected || NotificationType.unknown => c.text3,
        _ => c.statusInfo,
      };
}
