import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/api_inspection_repository.dart';
import '../data/auth_service.dart';
import '../models/inspection_outcome.dart';
import '../models/order.dart';
import '../models/order_response_status.dart';
import '../models/order_status.dart';
import '../models/user_summary.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../state/inspection_store.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/executor_stats.dart';
import '../widgets/order_review_section.dart';
import '../widgets/order_status_pill.dart';
import '../widgets/purchase_sheet.dart';
import '../widgets/review_sheet.dart';
import 'executor_reviews_screen.dart';
import 'inspection_overview_screen.dart';
import 'start_inspection_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.store,
    required this.orderId,
    required this.viewerIsCustomer,
    this.auth,
  });

  final OrderStore store;
  final int orderId;

  /// Экран открыт из "Мои заказы" (customer может принимать отклики) или
  /// из "Заказы рядом"/после отклика (executor, только на просмотр).
  final bool viewerIsCustomer;

  /// Нужен, чтобы открыть осмотр кандидата (ApiInspectionRepository).
  final AuthService? auth;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;
  bool _accepting = false;
  bool _completing = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Без finally любая ошибка (сеть, 500) оставляла карточку на вечном
  /// спиннере — теперь вместо него текст и «Повторить».
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

  Future<void> _openInspection(int inspectionId) async {
    final repo = ApiInspectionRepository(
      ApiClient(widget.auth!),
      inspectionId: inspectionId,
    );
    // править кандидата может только исполнитель; заказчик смотрит —
    // сервер ему запись всё равно не разрешит (403)
    final isExecutor = _order?.executor != null && _order!.executor!.id == widget.auth!.user?.id;
    // стор — до маршрута: builder перезапускается при смене темы
    final store = InspectionStore(repo, readOnly: !isExecutor);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionOverviewScreen(store: store),
      ),
    );
    await _load();
  }

  Future<void> _startInspection(Order order) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StartInspectionScreen(
          repository: widget.store.repository,
          catalog: widget.store.catalog,
          order: order,
        ),
      ),
    );
    if (created == true) await _load();
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

  /// «2 000 000 — 2 400 000 ₽», «от …» или «до …»; без границ — ничего.
  static String? _budget(Order order) {
    final min = order.budgetMin;
    final max = order.budgetMax;
    if (min != null && max != null) return '${money(min)} — ${money(max)} ₽';
    if (min != null) return 'от ${money(min)} ₽';
    if (max != null) return 'до ${money(max)} ₽';
    return null;
  }

  /// Покупка закрывает подбор; заказ — из ответа сервера, и в нём сразу
  /// can_review, так что блок отзыва появится без перезагрузки.
  Future<void> _completePurchase(Order order) async {
    final carId = await showPurchaseSheet(context, order: order);
    if (carId == null || !mounted) return;
    setState(() => _completing = true);
    try {
      final updated = await widget.store.completeSelection(order.id, carId: carId);
      if (mounted) setState(() => _order = updated);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  /// Те же условия, что у OrderController::complete на бекенде: заказчик,
  /// подбор в работе и хотя бы один кандидат, чтобы было что выбрать.
  bool _canCompletePurchase(Order order) =>
      widget.viewerIsCustomer &&
      !order.isInspection &&
      (order.status == OrderStatus.sourcing || order.status == OrderStatus.inspecting) &&
      order.cars.isNotEmpty;

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

  /// Новый отзыв или правка; заказ — из ответа сервера, как и рейтинг.
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

  void _showReviews(Order order, UserSummary executor) =>
      openExecutorReviews(context, widget.store.repository, executor);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 20, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: context.colors.bg1,
                      foregroundColor: context.colors.text1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _order != null ? 'Заказ #${_order!.id}' : 'Заказ',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: context.colors.text1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _error != null && !_loading
                  ? _buildError(_error!)
                  : _loading || _order == null
                      ? const Center(child: CircularProgressIndicator())
                      : _buildBody(_order!),
            ),
          ],
        ),
      ),
    );
  }

  /// Тот же блок, что у карточки осмотра (InspectionOrderDetailScreen).
  Widget _buildError(String error) {
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
            error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: context.colors.text3),
          ),
          const SizedBox(height: 10),
          CtaGhost(label: 'Повторить', onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildBody(Order order) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        OrderStatusPill(status: order.status),
        const SizedBox(height: 10),
        Text(
          order.carTitle,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: context.colors.text1),
        ),
        const SizedBox(height: 6),
        Text(
          [
            if (order.cities.isNotEmpty) order.cities.join(', '),
            if (order.mileageTo != null) 'пробег до ${money(order.mileageTo!)} км',
            ?_budget(order),
          ].join(' · '),
          style: TextStyle(fontSize: 12.5, color: context.colors.text2),
        ),
        if (order.requirements.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in order.requirements)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colors.bg1,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(r, style: TextStyle(fontSize: 11.5, color: context.colors.text2)),
                ),
            ],
          ),
        ],
        if (order.comment != null && order.comment!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(order.comment!, style: TextStyle(fontSize: 13, color: context.colors.text2)),
        ],
        if (order.executor != null) ...[
          const SizedBox(height: 22),
          _SectionLabel('Исполнитель'),
          const SizedBox(height: 8),
          _InfoRow(label: order.executor!.name, trailing: order.price != null ? '${money(order.price!)} ₽' : null),
          Padding(
            padding: const EdgeInsets.only(left: 13),
            child: ExecutorStats(
              user: order.executor!,
              onTap: () => _showReviews(order, order.executor!),
            ),
          ),
        ],
        OrderReviewSection(
          order: order,
          viewerIsCustomer: widget.viewerIsCustomer,
          onWrite: () => _writeReview(order),
        ),
        if (order.cars.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionLabel('Кандидаты'),
          const SizedBox(height: 8),
          for (final car in order.cars)
            _InfoRow(
              label: car.title,
              trailing: car.inspectionLabel,
              trailingColor: car.inspectionOutcome == InspectionOutcome.purchased
                  ? context.colors.statusDone
                  : null,
              onTap: car.inspectionId != null && widget.auth != null
                  ? () => _openInspection(car.inspectionId!)
                  : null,
            ),
        ],
        if (_canCompletePurchase(order)) ...[
          const SizedBox(height: 14),
          CtaPrimary(
            label: 'Зафиксировать покупку',
            icon: Icons.check,
            loading: _completing,
            onPressed: () => _completePurchase(order),
          ),
        ],
        // Заводить кандидата и стартовать осмотр может только назначенный
        // исполнитель — у заказчика этот вызов вернёт 403.
        if (widget.auth?.user != null &&
            order.executor?.id == widget.auth!.user!.id) ...[
          const SizedBox(height: 14),
          CtaPrimary(
            label: 'Осмотреть новый вариант',
            icon: Icons.add,
            onPressed: () => _startInspection(order),
          ),
        ],
        if (widget.viewerIsCustomer && order.responses.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionLabel('Отклики'),
          const SizedBox(height: 8),
          for (final r in order.responses)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: context.colors.bg1, borderRadius: BorderRadius.circular(13)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.executor.name, style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.text1)),
                        const SizedBox(height: 2),
                        ExecutorStats(
                          user: r.executor,
                          onTap: () => _showReviews(order, r.executor),
                        ),
                        const SizedBox(height: 2),
                        Text('${money(r.proposedPrice)} ₽', style: TextStyle(fontSize: 12, color: context.colors.text2)),
                        if (r.message != null) ...[
                          const SizedBox(height: 4),
                          Text(r.message!, style: TextStyle(fontSize: 11.5, color: context.colors.text3)),
                        ],
                      ],
                    ),
                  ),
                  if (r.status == OrderResponseStatus.pending)
                    ElevatedButton(
                      onPressed: _accepting ? null : () => _accept(r.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.statusDone,
                        foregroundColor: context.colors.modeBuyInk,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Принять', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    )
                  else
                    Text(
                      r.status.label,
                      style: TextStyle(fontSize: 11, color: context.colors.text3),
                    ),
                ],
              ),
            ),
        ],
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
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: context.colors.text3, fontWeight: FontWeight.w600),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.trailing, this.trailingColor, this.onTap});
  final String label;
  final String? trailing;
  final Color? trailingColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(color: context.colors.bg1, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: context.colors.text1)),
          if (trailing != null)
            Text(trailing!, style: TextStyle(fontSize: 12, color: trailingColor ?? context.colors.text2)),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 16, color: context.colors.text3),
          ],
        ],
      ),
      ),
    );
  }
}
