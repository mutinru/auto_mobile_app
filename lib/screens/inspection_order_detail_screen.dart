import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../models/order.dart';
import '../models/order_response_status.dart';
import '../models/order_status.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/deadline_countdown.dart';
import '../widgets/dispute_sheet.dart';
import '../widgets/executor_stats.dart';
import '../widgets/inspection_order_parts.dart';
import '../widgets/order_review_section.dart';
import '../widgets/payment_parts.dart';
import '../widgets/response_card.dart';
import '../widgets/review_sheet.dart';
import 'executor_reviews_screen.dart';
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
    extends State<InspectionOrderDetailScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;
  bool _accepting = false;
  bool _paying = false;
  bool _cancelling = false;

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

  Future<void> _markPaid(Order order) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Вы перевели ${order.price == null ? 'оплату' : '${money(order.price!)} ₽'}?',
      text: 'Исполнитель проверит поступление и подтвердит — после этого '
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

  /// Отменить можно, пока сервер отдаёт canCancel; заказ — из ответа.
  Future<void> _cancel(Order order) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Отменить заказ?',
      text: 'Отклики исполнителей будут отклонены. Вернуть заказ нельзя.',
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

  Future<void> _openDispute(Order order) {
    return showDisputeSheet(
      context,
      onSubmit: (reason) async {
        final updated = await widget.store.openDispute(order.id, reason: reason);
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
            ? await widget.store.leaveReview(order.id, rating: rating, text: text)
            : await widget.store.updateReview(order.id, rating: rating, text: text);
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
    if (!widget.viewerIsCustomer) return const [];
    return switch (order.status) {
      OrderStatus.reportReady => [
          BottomCta(children: [
            CtaPrimary(
              label: 'Я оплатил',
              icon: Icons.check_rounded,
              loading: _paying,
              onPressed: () => _markPaid(order),
            ),
          ]),
        ],
      OrderStatus.paymentSent => [
          BottomCta(children: [
            CtaGhost(
              label: 'Исполнитель не подтверждает — открыть спор',
              onPressed: () => _openDispute(order),
            ),
          ]),
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
        widget.viewerIsCustomer &&
        order.status == OrderStatus.awaitingExecutor &&
        !_accepting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      children: [
        InspectionOrderSummary(
          order: order,
          priceLabel: 'Ваша цена',
          price: order.askingPrice,
        ),
        if (widget.viewerIsCustomer && order.status.isAwaitingPayment)
          ..._payment(order),
        // вердикт — только когда отчёт получен; до оплаты сервер его не
        // отдаёт, проверка статуса — страховка
        if (order.verdict != null && !order.status.isAwaitingPayment) ...[
          const SizedBox(height: 22),
          const SectionHead('Итог осмотра'),
          InspectionVerdictBox(order: order),
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
          _ExecutorBox(
            order: order,
            onShowReviews: () => openExecutorReviews(
              context,
              widget.store.repository,
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
          viewerIsCustomer: widget.viewerIsCustomer,
          onWrite: () => _writeReview(order),
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 22),
          // исполнителю сервер отдаёт только его собственный отклик
          widget.viewerIsCustomer
              ? SectionHead('Отклики', extra: '${pending.length}')
              : const SectionHead('Ваш отклик'),
          for (final response in pending)
            ResponseCard(
              response: response,
              askingPrice: order.askingPrice,
              onAccept: canPick ? () => _accept(response.id) : null,
              onShowReviews: () => openExecutorReviews(
                context,
                widget.store.repository,
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
        if (widget.viewerIsCustomer && order.canCancel) ...[
          const SizedBox(height: 14),
          CtaGhost(
            label: 'Отменить заказ',
            onPressed: _cancelling ? null : () => _cancel(order),
          ),
        ],
      ],
    );
  }

  /// Отчёт готов, идёт оплата или спор.
  List<Widget> _payment(Order order) => [
        const SizedBox(height: 22),
        SectionHead(order.status == OrderStatus.disputed ? 'Спор' : 'Отчёт готов'),
        if (order.status == OrderStatus.paymentSent) ...[
          const StatusNote(text: 'Ждём, пока исполнитель подтвердит оплату. Потом откроется полный отчёт.'),
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
        if (order.payout != null) PayoutBlock(price: order.price, payout: order.payout!),
      ];
}

/// Исполнитель и телефон продавца — телефон бекенд отдаёт только
/// заказчику и выбранному исполнителю.
class _ExecutorBox extends StatelessWidget {
  const _ExecutorBox({required this.order, this.onShowReviews});

  final Order order;
  final VoidCallback? onShowReviews;

  @override
  Widget build(BuildContext context) {
    final executor = order.executor!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Avatar(initialsOf(executor.name), size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      executor.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ExecutorStats(user: executor, onTap: onShowReviews),
                    if (order.status == OrderStatus.scheduled)
                      Text(
                        'приедет на осмотр',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.colors.text2,
                        ),
                      ),
                  ],
                ),
              ),
              if (order.price != null)
                Text(
                  '${money(order.price!)} ₽',
                  style: TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text1,
                  ),
                ),
            ],
          ),
          if (order.sellerPhone != null && order.sellerPhone!.isNotEmpty) ...[
            const SizedBox(height: 11),
            Container(height: 1, color: context.colors.line),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Телефон продавца',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.colors.text2,
                    ),
                  ),
                ),
                Text(
                  order.sellerPhone!,
                  style: TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 13,
                    color: context.colors.text1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
