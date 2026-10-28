import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../models/order.dart';
import '../models/order_response_status.dart';
import '../models/order_status.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/inspection_order_parts.dart';
import '../widgets/response_card.dart';
import 'inspection_report_screen.dart';

/// Кадр 04 макета order-types.html — деталь заказа-осмотра: сводка,
/// цена заказчика, отклики с разницей от неё, после назначения —
/// исполнитель и телефон продавца, после завершения — вердикт.
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
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(int responseId) async {
    setState(() => _accepting = true);
    try {
      await widget.store.acceptResponse(widget.orderId, responseId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
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
          ],
        ),
      ),
    );
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
        if (order.verdict != null) ...[
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
          _ExecutorBox(order: order),
        ],
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 22),
          SectionHead('Отклики', extra: '${pending.length}'),
          for (final response in pending)
            ResponseCard(
              response: response,
              askingPrice: order.askingPrice,
              onAccept: canPick ? () => _accept(response.id) : null,
            ),
        ] else if (order.status == OrderStatus.awaitingExecutor) ...[
          const SizedBox(height: 22),
          const SectionHead('Отклики'),
          Text(
            'Пока никто не откликнулся',
            style: TextStyle(fontSize: 12.5, color: context.colors.text2),
          ),
        ],
      ],
    );
  }
}

/// Исполнитель и телефон продавца — телефон бекенд отдаёт только
/// заказчику и выбранному исполнителю.
class _ExecutorBox extends StatelessWidget {
  const _ExecutorBox({required this.order});

  final Order order;

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
