import 'package:flutter/material.dart';

import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/order_response_status.dart';
import '../models/order_status.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/ru_date.dart';
import '../widgets/app_ui.dart';
import '../widgets/response_card.dart';

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
  });

  final OrderStore store;
  final int orderId;

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
                      color: order.status.pillColor,
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
            const Text(
              'Не удалось загрузить заказ',
              style: TextStyle(fontSize: 14, color: AppColors.text1),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: AppColors.text3),
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
    final canPick = widget.viewerIsCustomer &&
        order.status == OrderStatus.awaitingExecutor &&
        !_accepting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      children: [
        _Summary(order: order),
        if (order.verdict != null) ...[
          const SizedBox(height: 22),
          const SectionHead('Итог осмотра'),
          _VerdictBox(order: order),
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
          const Text(
            'Пока никто не откликнулся',
            style: TextStyle(fontSize: 12.5, color: AppColors.text2),
          ),
        ],
      ],
    );
  }
}

/// .summary — дата, адрес, пробег и объявление, внизу цена заказчика.
class _Summary extends StatelessWidget {
  const _Summary({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final listing = order.listingUrl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(
            icon: Icons.calendar_today_outlined,
            text: whenLabel(order.inspectOn, order.timeSlot, order.inspectTime),
            strong: true,
          ),
          if (order.address != null)
            _SummaryRow(icon: Icons.location_on_outlined, text: order.address!),
          _SummaryRow(
            icon: Icons.link,
            text: [
              if (order.mileageTo != null) '${money(order.mileageTo!)} км',
              // ссылка — просто текст: разбор объявления не делаем
              if (listing != null && listing.isNotEmpty) listing,
            ].join(' · '),
          ),
          if (order.askingPrice != null) ...[
            const SizedBox(height: 11),
            Container(height: 1, color: AppColors.line),
            const SizedBox(height: 11),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ваша цена',
                    style: TextStyle(fontSize: 11.5, color: AppColors.text2),
                  ),
                ),
                Text(
                  '${money(order.askingPrice!)} ₽',
                  style: const TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text1,
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

/// .summary-row
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.text, this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: AppColors.text3),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                color: strong ? AppColors.text1 : AppColors.text2,
              ),
            ),
          ),
        ],
      ),
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
        color: AppColors.bg1,
        border: Border.all(color: AppColors.line),
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
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text1,
                      ),
                    ),
                    if (order.status == OrderStatus.scheduled)
                      const Text(
                        'приедет на осмотр',
                        style: TextStyle(fontSize: 11.5, color: AppColors.text2),
                      ),
                  ],
                ),
              ),
              if (order.price != null)
                Text(
                  '${money(order.price!)} ₽',
                  style: const TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text1,
                  ),
                ),
            ],
          ),
          if (order.sellerPhone != null && order.sellerPhone!.isNotEmpty) ...[
            const SizedBox(height: 11),
            Container(height: 1, color: AppColors.line),
            const SizedBox(height: 11),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Телефон продавца',
                    style: TextStyle(fontSize: 11.5, color: AppColors.text2),
                  ),
                ),
                Text(
                  order.sellerPhone!,
                  style: const TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 13,
                    color: AppColors.text1,
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

/// Вердикт с ссылкой на отчёт — то, ради чего заказ и делался.
class _VerdictBox extends StatelessWidget {
  const _VerdictBox({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final verdict = order.verdict!;
    final comment = order.cars.first.verdictComment;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        border: Border.all(color: verdict.color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: verdict.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(verdict.icon, size: 15, color: verdict.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verdict.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: verdict.color,
                  ),
                ),
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    comment,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.text2,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
