import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../models/order.dart';
import '../models/order_action.dart';
import '../models/order_response_status.dart';
import '../models/order_status.dart';
import '../payments/payment_flow.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../util/money.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/deadline_countdown.dart';
import '../widgets/dispute_sheet.dart';
import '../widgets/executor_box.dart';
import '../widgets/inspection_order_parts.dart';
import '../widgets/order_review_section.dart';
import '../widgets/payment_parts.dart';
import '../widgets/repost_sheet.dart';
import '../widgets/response_card.dart';
import '../widgets/review_sheet.dart';
import 'executor_reviews_screen.dart';
import 'auto_refresh.dart';
import 'inspection_report_screen.dart';

/// Кадр 04 макета order-types.html — деталь заказа-осмотра: сводка,
/// цена заказчика, отклики с разницей от неё, после назначения —
/// исполнитель и телефон продавца, после завершения — вердикт.
///
/// Между «отчёт готов» и получением отчёта заказчик видит сумму, реквизиты
/// исполнителя и сводку, но не вердикт: «Я оплатил» → исполнитель
/// подтверждает → отчёт открыт. Спор — если исполнитель не подтверждает.
///
/// Отдельный экран, а не ветка в [OrderDetailScreen]: та деталь собрана
/// под бюджет, города и список кандидатов, и её правка — самый быстрый
/// способ сломать подбор.
class InspectionOrderDetailScreen extends StatefulWidget {
  const InspectionOrderDetailScreen({
    super.key,
    required this.store,
    required this.orderId,
    this.viewerIsCustomer = true,
    this.auth,
  });

  final OrderStore store;
  final int orderId;

  /// Нужен, чтобы открыть полный отчёт через API. Без него (в тестах)
  /// кнопки отчёта нет.
  final AuthService? auth;

  /// Только заказчик выбирает исполнителя из откликов.
  final bool viewerIsCustomer;

  @override
  State<InspectionOrderDetailScreen> createState() =>
      _InspectionOrderDetailScreenState();
}

class _InspectionOrderDetailScreenState
    extends State<InspectionOrderDetailScreen>
    with AutoRefresh<InspectionOrderDetailScreen> {
  Order? _order;

  /// Заказчик ли смотрит (ревью №31): роль — из загруженного заказа,
  /// параметр экрана — подсказка до загрузки и для мока.
  bool get _viewerIsCustomer => switch (_order?.viewerRole) {
    ViewerRole.customer => true,
    ViewerRole.executor => false,
    null => widget.viewerIsCustomer,
  };
  bool _loading = true;
  String? _error;
  bool _accepting = false;
  bool _paying = false;
  bool _cancelling = false;
  bool _payingPlacement = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await widget.store.fetchOrder(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  bool get refreshPaused =>
      _loading || _accepting || _paying || _cancelling || _payingPlacement;

  /// Тихое перечитывание (AutoRefresh): без спиннера, ошибку бросает.
  @override
  Future<void> refresh() async {
    final before = _order;
    final order = await widget.store.fetchOrder(widget.orderId);
    // пока ждали, заказ подменило действие — его ответ свежее
    if (!mounted || refreshPaused || !identical(_order, before)) return;
    setState(() {
      _order = order;
      _error = null;
    });
    widget.store.replaceOrder(order);
  }

  Future<void> _markPaid(Order order) async {
    final ok = await showConfirmSheet(
      context,
      title:
          'Вы перевели ${order.price == null ? 'оплату' : '${money(order.price!)} ₽'}?',
      text:
          'Исполнитель проверит поступление и подтвердит — после этого '
          'откроются полный отчёт и вердикт.',
      confirmLabel: 'Да, я оплатил',
    );
    if (!ok || !mounted) return;
    setState(() => _paying = true);
    try {
      final updated = await widget.store.markPaymentSent(order.id);
      if (mounted) setState(() => _order = updated);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Оплатить размещение: начатая оплата — та же, иначе сервер заведёт
  /// новую. Итог — заказ с сервера: оплачен — он уже в ленте исполнителей.
  Future<void> _payPlacement(Order order) async {
    setState(() => _payingPlacement = true);
    try {
      final payment =
          order.pendingPayment ??
          (await widget.store.payPlacement(order.id)).pendingPayment;
      if (payment != null && mounted) {
        await runPayment(context, widget.store.payments, payment);
      }
      final updated = await widget.store.fetchOrder(order.id);
      widget.store.replaceOrder(updated);
      if (mounted) setState(() => _order = updated);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _payingPlacement = false);
    }
  }

  /// Отменить можно, пока сервер отдаёт canCancel; заказ — из ответа.
  Future<void> _cancel(Order order) async {
    // размещение оплачено — при отмене сервер вернёт деньги
    final refund =
        order.placementFee != null &&
        order.status != OrderStatus.awaitingPlacement;
    final ok = await showConfirmSheet(
      context,
      title: 'Отменить заказ?',
      text: order.status == OrderStatus.awaitingPlacement
          ? 'Заказ ещё не опубликован — исполнители его не видели.'
          : refund
          ? 'Отклики исполнителей будут отклонены, деньги за размещение '
                'вернутся на карту. Вернуть заказ нельзя.'
          : 'Отклики исполнителей будут отклонены. Вернуть заказ нельзя.',
      confirmLabel: 'Отменить заказ',
      cancelLabel: 'Не отменять',
    );
    if (!ok || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final updated = await widget.store.cancelOrder(order.id);
      if (mounted) setState(() => _order = updated);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  /// Осмотр ждёт решения: новая дата (и цена) — заказ снова в ленте.
  Future<void> _repost(Order order) {
    return showRepostSheet(
      context,
      order: order,
      onSubmit: (when, price) async {
        final updated = await widget.store.repostInspection(
          order.id,
          inspectOn: when.date,
          timeSlot: when.slot,
          inspectTime: when.inspectTime,
          askingPrice: price,
        );
        if (mounted) setState(() => _order = updated);
      },
    );
  }

  Future<void> _openDispute(Order order) {
    return showDisputeSheet(
      context,
      onSubmit: (reason) async {
        final updated = await widget.store.openDispute(
          order.id,
          reason: reason,
        );
        if (mounted) setState(() => _order = updated);
      },
    );
  }

  Future<void> _accept(int responseId) async {
    setState(() => _accepting = true);
    try {
      await widget.store.acceptResponse(widget.orderId, responseId);
      await _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  /// Новый отзыв или правка. Экран берёт заказ из ответа сервера:
  /// рейтинг исполнителя и can_review пересчитаны там.
  Future<void> _writeReview(Order order) {
    return showReviewSheet(
      context,
      order: order,
      initial: order.review,
      onSubmit: (rating, text) async {
        final updated = order.review == null
            ? await widget.store.leaveReview(
                order.id,
                rating: rating,
                text: text,
              )
            : await widget.store.updateReview(
                order.id,
                rating: rating,
                text: text,
              );
        if (mounted) setState(() => _order = updated);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: order?.carTitle ?? 'Осмотр',
              eyebrow: 'осмотр #${widget.orderId}',
              onBack: () => Navigator.of(context).pop(),
              trailing: order == null
                  ? null
                  : Pill(
                      order.status.labelFor(order.kind),
                      color: order.status.pillColor(context.colors),
                    ),
            ),
            Expanded(child: _body(order)),
            if (order != null) ..._bottom(order),
          ],
        ),
      ),
    );
  }

  /// Нижняя кнопка заказчика по статусу оплаты.
  List<Widget> _bottom(Order order) {
    if (!_viewerIsCustomer) return const [];
    return switch (order.status) {
      OrderStatus.awaitingPlacement when order.can(OrderAction.payPlacement) =>
        [
          BottomCta(
            children: [
              CtaPrimary(
                label: order.placementFee == null
                    ? 'Оплатить размещение'
                    : 'Оплатить размещение · ${money(order.placementFee!)} ₽',
                loading: _payingPlacement,
                onPressed: () => _payPlacement(order),
              ),
            ],
          ),
        ],
      OrderStatus.reportReady when order.can(OrderAction.markPaid) => [
        BottomCta(
          children: [
            CtaPrimary(
              label: 'Я оплатил',
              icon: Icons.check_rounded,
              loading: _paying,
              onPressed: () => _markPaid(order),
            ),
          ],
        ),
      ],
      // спор — только когда сервер открыл окно (сутки без подтверждения)
      OrderStatus.paymentSent when order.canDispute => [
        BottomCta(
          children: [
            CtaGhost(
              label: 'Исполнитель не подтверждает — открыть спор',
              onPressed: () => _openDispute(order),
            ),
          ],
        ),
      ],
      _ => const [],
    };
  }

  Widget _body(Order? order) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Не удалось загрузить заказ',
              style: TextStyle(fontSize: 14, color: context.colors.text1),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: context.colors.text3),
            ),
            const SizedBox(height: 10),
            CtaGhost(label: 'Повторить', onPressed: _load),
          ],
        ),
      );
    }

    if (_loading || order == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final pending = order.responses
        .where((r) => r.status == OrderResponseStatus.pending)
        .toList();
    final canPick =
        _viewerIsCustomer &&
        order.can(OrderAction.acceptResponse) &&
        !_accepting;

    return RefreshIndicator(
      onRefresh: pullToRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
        children: [
          InspectionOrderSummary(
            order: order,
            priceLabel: 'Ваша цена',
            price: order.askingPrice,
          ),
          if (_viewerIsCustomer &&
              (order.cars.firstOrNull?.vinMismatch ?? false))
            const VinMismatchNote(),
          if (_viewerIsCustomer)
            ?mileageMismatchNoteFor(order.cars.firstOrNull),
          if (_viewerIsCustomer &&
              order.status == OrderStatus.awaitingPlacement)
            ..._placement(order),
          if (_viewerIsCustomer && order.status == OrderStatus.awaitingDecision)
            ..._decision(order),
          if (_viewerIsCustomer && order.status.isAwaitingPayment)
            ..._payment(order),
          // вердикт — только когда отчёт получен; до оплаты сервер его не
          // отдаёт, проверка статуса — страховка
          if (order.verdict != null && !order.status.isAwaitingPayment) ...[
            const SizedBox(height: 22),
            const SectionHead('Итог осмотра'),
            InspectionVerdictBox.forOrder(order),
            if (widget.auth != null && hasInspectionReport(order)) ...[
              const SizedBox(height: 8),
              CtaGhost(
                label: 'Полный отчёт',
                onPressed: () =>
                    openInspectionReport(context, widget.auth!, order),
              ),
            ],
          ],
          if (order.executor != null) ...[
            const SizedBox(height: 22),
            const SectionHead('Исполнитель'),
            ExecutorBox(
              order: order,
              onShowReviews: () => openExecutorReviews(
                context,
                widget.store.reviews,
                order.executor!,
              ),
            ),
            if (order.executorDeadlineAt != null &&
                (order.status == OrderStatus.scheduled ||
                    order.status == OrderStatus.inspecting)) ...[
              const SizedBox(height: 8),
              DeadlineCountdown(
                deadline: order.executorDeadlineAt!,
                prefix: 'Осмотрит в течение',
              ),
            ],
          ],
          OrderReviewSection(
            order: order,
            viewerIsCustomer: _viewerIsCustomer,
            onWrite: () => _writeReview(order),
          ),
          // в ожидании решения старые отклики выбрать нельзя: при повторном
          // размещении сервер их отклонит
          if (pending.isNotEmpty &&
              order.status != OrderStatus.awaitingDecision) ...[
            const SizedBox(height: 22),
            // исполнителю сервер отдаёт только его собственный отклик
            _viewerIsCustomer
                ? SectionHead('Отклики', extra: '${pending.length}')
                : const SectionHead('Ваш отклик'),
            for (final response in pending)
              ResponseCard(
                response: response,
                askingPrice: order.askingPrice,
                onAccept: canPick ? () => _accept(response.id) : null,
                onShowReviews: () => openExecutorReviews(
                  context,
                  widget.store.reviews,
                  response.executor,
                ),
              ),
          ] else if (order.status == OrderStatus.awaitingExecutor) ...[
            const SizedBox(height: 22),
            const SectionHead('Отклики'),
            Text(
              'Пока никто не откликнулся',
              style: TextStyle(fontSize: 12.5, color: context.colors.text2),
            ),
          ],
          // в конце списка, а не в нижней панели: пока заказ ждёт
          // исполнителя, главное действие — выбрать отклик
          if (_viewerIsCustomer && order.canCancel) ...[
            const SizedBox(height: 14),
            CtaGhost(
              label: 'Отменить заказ',
              onPressed: _cancelling ? null : () => _cancel(order),
            ),
          ],
        ],
      ),
    );
  }

  /// Заказ создан, но не опубликован: ждёт оплаты размещения. Оплатить —
  /// нижняя кнопка, отменить — общая кнопка внизу списка.
  List<Widget> _placement(Order order) => [
    const SizedBox(height: 22),
    const SectionHead('Оплата размещения'),
    StatusNote(
      icon: Icons.payments_outlined,
      text:
          'Исполнители увидят заказ после оплаты размещения'
          '${order.placementFee == null ? '' : ' — ${money(order.placementFee!)} ₽'}. '
          'Деньги спишутся, когда исполнитель пришлёт отчёт; отмените '
          'заказ — вернутся. Не оплатите до дня осмотра — заказ отменится.',
    ),
  ];

  /// Исполнитель сорвал срок или день прошёл без него — заказчик решает.
  /// «Отменить заказ» — общая кнопка внизу (сервер отдаёт can_cancel).
  List<Widget> _decision(Order order) => [
    const SizedBox(height: 22),
    const SectionHead('Нужно решение'),
    StatusNote(
      icon: Icons.event_busy_outlined,
      text: order.decisionReason == DecisionReason.missed
          ? 'Исполнитель не провёл осмотр в назначенный день. '
                'Разместите заказ на другую дату или отмените его.'
          : 'День осмотра прошёл, а исполнитель так и не выбран. '
                'Разместите заказ на другую дату или отмените его.',
    ),
    const SizedBox(height: 8),
    if (order.can(OrderAction.repost))
      CtaPrimary(label: 'Разместить заново', onPressed: () => _repost(order)),
  ];

  /// Отчёт готов, идёт оплата или спор.
  List<Widget> _payment(Order order) => [
    const SizedBox(height: 22),
    SectionHead(order.status == OrderStatus.disputed ? 'Спор' : 'Отчёт готов'),
    if (order.status == OrderStatus.paymentSent) ...[
      const StatusNote(
        text:
            'Ждём, пока исполнитель подтвердит оплату. Потом откроется полный отчёт.',
      ),
      DisputeWindowNote(
        order: order,
        ifSilent: 'исполнитель так и не подтвердит оплату',
      ),
      const SizedBox(height: 8),
    ],
    if (order.status == OrderStatus.disputed) ...[
      DisputeBox(order: order, viewerId: order.customer.id),
      const SizedBox(height: 8),
    ],
    if (order.reportSummary != null) ...[
      ReportSummaryBox(summary: order.reportSummary!),
      const SizedBox(height: 8),
    ],
    // в споре реквизиты нужны, только если оплату ещё не отмечали
    if (order.payout != null &&
        (order.status != OrderStatus.disputed || order.paymentSentAt == null))
      PayoutBlock(price: order.price, payout: order.payout!),
  ];
}
