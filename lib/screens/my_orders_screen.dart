import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../models/order.dart';
import '../models/order_kind.dart';
import '../state/notification_scope.dart';
import '../models/order_status.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/order_card.dart';
import '../widgets/notification_bell.dart';
import '../widgets/order_kind_sheet.dart';
import '../widgets/unread_badge.dart';
import 'inspection_report_screen.dart';
import 'new_inspection_screen.dart';
import 'new_order_screen.dart';
import 'notifications_screen.dart';
import 'order_routes.dart';

/// Экран 02 макета — «мои заказы».
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({
    super.key,
    required this.store,
    this.auth,
    this.asExecutor = false,
    this.onProfile,
  });

  final OrderStore store;
  final AuthService? auth;

  /// true — показываем заказы, где пользователь исполнитель
  /// (GET /orders/assigned), иначе его собственные заказы.
  final bool asExecutor;

  /// Иконка профиля в шапке. null — иконки нет.
  final VoidCallback? onProfile;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    if (widget.asExecutor) {
      widget.store.loadAssignedOrders();
    } else {
      widget.store.loadMyOrders();
    }
  }

  /// Экран заказа выбирает [openOrderScreen] — тот же, что у ленты уведомлений.
  Future<void> _openOrder(Order order) async {
    await openOrderScreen(
      context,
      store: widget.store,
      auth: widget.auth,
      orderId: order.id,
      isInspection: order.isInspection,
      asExecutor: widget.asExecutor,
    );
    _reload();
  }

  /// Уведомление могло увести в заказ и сменить его статус — перечитываем.
  Future<void> _openNotifications() async {
    await openNotifications(context, store: widget.store, auth: widget.auth);
    _reload();
  }

  /// Колокольчик (есть [NotificationScope]) и профиль — справа в шапке.
  Widget? _headActions() {
    final actions = [
      if (NotificationScope.maybeOf(context) != null)
        NotificationBell(onTap: _openNotifications),
      if (widget.onProfile != null && !widget.asExecutor)
        // поддержка — в профиле, ответ оператора виден на его иконке
        SupportUnreadBadge(
          child: SquareIconButton(
            icon: Icons.person_outline,
            onTap: widget.onProfile!,
          ),
        ),
    ];
    if (actions.isEmpty) return null;
    if (actions.length == 1) return actions.single;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [actions.first, const SizedBox(width: 8), actions.last],
    );
  }

  /// «Новый заказ» открывает лист выбора вида (кадр 02).
  Future<void> _createOrder() async {
    final kind = await showOrderKindSheet(context);
    if (kind == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => kind.isInspection
            ? NewInspectionScreen(store: widget.store)
            : NewOrderScreen(store: widget.store),
      ),
    );
    _reload();
  }

  /// «Осмотреть другую машину» — новый осмотр с тем же адресом и ценой.
  Future<void> _repeatInspection(Order order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NewInspectionScreen(store: widget.store, basedOn: order),
      ),
    );
    _reload();
  }

  /// Активный таб — секциями «Осмотры» (по дате) и «Подборы»,
  /// завершённый — единым списком (order-types.html, кадры 01 и 05).
  Widget _list(List<Order> orders) {
    final store = widget.store;
    final error = widget.asExecutor ? store.assignedError : store.mineError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Не удалось загрузить заказы',
              style: TextStyle(fontSize: 14, color: context.colors.text1),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: context.colors.text3),
            ),
            const SizedBox(height: 10),
            CtaGhost(label: 'Повторить', onPressed: _reload),
          ],
        ),
      );
    }

    if (widget.asExecutor ? store.isLoadingAssigned : store.isLoadingMine) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return Center(
        child: Text(
          'Пока пусто',
          style: TextStyle(color: context.colors.text3, fontSize: 12),
        ),
      );
    }

    final inspections = orders.where((o) => o.isInspection).toList();
    final selections = orders.where((o) => !o.isInspection).toList();
    final splitBySections =
        _tab == 0 && inspections.isNotEmpty && selections.isNotEmpty;

    return ListView(
      // .scroll-body { padding: 4px 22px 18px }
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
      children: [
        if (splitBySections) ...[
          const SectionHead('Осмотры', extra: 'по дате'),
          for (final order in inspections) _card(order),
          const SizedBox(height: 10),
          const SectionHead('Подборы'),
          for (final order in selections) _card(order),
        ] else
          for (final order in orders) _card(order),
      ],
    );
  }

  Widget _card(Order order) => OrderCard(
    order: order,
    asExecutor: widget.asExecutor,
    onTap: () => _openOrder(order),
    onRepeat:
        !widget.asExecutor &&
            order.isInspection &&
            order.status == OrderStatus.completed
        ? () => _repeatInspection(order)
        : null,
    onReport: widget.auth != null && hasInspectionReport(order)
        ? () => openInspectionReport(context, widget.auth!, order)
        : null,
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final source = widget.asExecutor
            ? store.assignedOrders
            : store.myOrders;
        final orders = source.where((o) {
          // отчёт готов / оплата / спор — ещё активные: заказчик не получил отчёт
          final finished = o.status.isFinished;
          return _tab == 0 ? !finished : finished;
        }).toList();

        final eyebrow = widget.asExecutor
            ? 'вы исполнитель'
            : (store.myOrders.isNotEmpty
                  ? store.myOrders.first.customer.name
                  : null);

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                DetailHead(
                  title: widget.asExecutor ? 'Взятые заказы' : 'Мои заказы',
                  eyebrow: eyebrow,
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).pop()
                      : null,
                  trailing: _headActions(),
                ),
                AppToggle(
                  labels: const ['Активные', 'Завершённые'],
                  activeIndex: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                Expanded(child: _list(orders)),
                if (!widget.asExecutor)
                  BottomCta(
                    children: [
                      CtaPrimary(
                        label: 'Новый заказ',
                        icon: Icons.add,
                        onPressed: _createOrder,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
