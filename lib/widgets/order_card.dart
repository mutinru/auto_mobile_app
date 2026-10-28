import 'package:flutter/material.dart';

import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/order_kind.dart';
import '../models/order_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/ru_date.dart';
import 'app_ui.dart';

/// .order-card из order-types.html — одна карточка заказа в списке.
/// Общая для подбора и осмотра: у осмотра вместо бюджета блок «когда и
/// где», а у завершённого — вердикт вместо прогресса.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onRepeat,
    this.onReport,
  });

  final Order order;
  final VoidCallback onTap;

  /// «Осмотреть другую машину» под завершённым осмотром (кадр 05).
  final VoidCallback? onRepeat;

  /// «Посмотреть полный отчёт» под вердиктом завершённого осмотра.
  final VoidCallback? onReport;

  bool get _isDone =>
      order.status == OrderStatus.completed || order.status == OrderStatus.cancelled;

  @override
  Widget build(BuildContext context) {
    final inspection = order.isInspection;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        // .order-card { padding: 14px; radius: 15px; margin-bottom: 9px }
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.bg1,
          border: Border.all(color: context.colors.line),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // .order-top — статус и вид заказа вместо голого номера
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Pill(
                  order.status.labelFor(order.kind),
                  color: order.status.pillColor(context.colors),
                ),
                _KindTag(kind: order.kind, id: order.id),
              ],
            ),
            const SizedBox(height: 9),
            _CarTitle(order: order),
            if (inspection) ...[
              if (_isDone) ...[
                const SizedBox(height: 5),
                Text(
                  [
                    if (_city(order.address) != null) _city(order.address)!,
                    pastDate(order.inspectOn),
                  ].join(' · '),
                  style: context.text.orderMeta,
                ),
                if (order.verdict != null)
                  _VerdictRow(
                    verdict: order.verdict!,
                    comment: order.cars.first.verdictComment,
                  ),
                if (onReport != null) _ReportButton(onTap: onReport!),
                if (onRepeat != null) _AgainButton(onTap: onRepeat!),
              ] else
                _WhenRow(order: order),
            ] else ...[
              const SizedBox(height: 5),
              Text(_selectionMeta(order), style: context.text.orderMeta),
            ],
            const SizedBox(height: 12),
            // .order-foot
            Container(height: 1, color: context.colors.line),
            const SizedBox(height: 12),
            OrderFoot(order: order),
          ],
        ),
      ),
    );
  }

  static String _selectionMeta(Order order) => [
        if (order.cities.isNotEmpty) order.cities.first,
        if (order.budgetMax != null) 'до ${money(order.budgetMax!)} ₽',
        if (order.requirements.isNotEmpty) order.requirements.first,
      ].join(' · ');

  /// «Мытищи, ул. Мира, 12» → «Мытищи»: в карточке завершённого осмотра
  /// в макете стоит только город.
  static String? _city(String? address) {
    if (address == null || address.isEmpty) return null;
    return address.split(',').first.trim();
  }
}

/// .kind — «осмотр #2051» справа сверху.
class _KindTag extends StatelessWidget {
  const _KindTag({required this.kind, required this.id});

  final OrderKind kind;
  final int id;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          kind.isInspection ? Icons.assignment_outlined : Icons.search,
          size: 12,
          color: context.colors.text3,
        ),
        const SizedBox(width: 5),
        Text(
          kind.label.toUpperCase(),
          style: context.text.orderId.copyWith(
            color: context.colors.text2,
            letterSpacing: 0.63,
          ),
        ),
        const SizedBox(width: 4),
        Text('#$id', style: context.text.orderId),
      ],
    );
  }
}

/// .order-car — у осмотра к названию добавляется пробег.
class _CarTitle extends StatelessWidget {
  const _CarTitle({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final km = order.isInspection && order.mileageTo != null
        ? ' · ${money(order.mileageTo!)} км'
        : null;

    if (km == null) return Text(order.carTitle, style: context.text.orderCar);

    // .order-car .km — пробег тем же кеглем, но серым
    return Text.rich(
      TextSpan(
        text: order.carTitle,
        children: [
          TextSpan(
            text: km,
            style: TextStyle(
              color: context.colors.text2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      style: context.text.orderCar,
    );
  }
}

/// .when — дата, время и адрес выезда. Оранжевая иконка (.when.soon),
/// если ехать сегодня или завтра.
class _WhenRow extends StatelessWidget {
  const _WhenRow({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final date = order.inspectOn;
    final soon = date != null &&
        date.difference(DateTime(DateTime.now().year, DateTime.now().month,
                DateTime.now().day))
            .inDays <=
            1;
    final color = soon ? context.colors.statusProgress : context.colors.statusInfo;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.bg0,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: soon ? 0.16 : 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.calendar_today_outlined, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  whenLabel(order.inspectOn, order.timeSlot, order.inspectTime),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text1,
                  ),
                ),
                if (order.address != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    order.address!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: context.colors.text2),
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

/// .verdict — итог осмотра вместо прогресса: ради него заказ и делался.
class _VerdictRow extends StatelessWidget {
  const _VerdictRow({required this.verdict, required this.comment});

  final InspectionVerdict verdict;
  final String? comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.bg0,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: verdict.color(context.colors).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(verdict.icon, size: 15, color: verdict.color(context.colors)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verdict.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: verdict.color(context.colors),
                  ),
                ),
                if (comment != null && comment!.isNotEmpty)
                  Text(
                    comment!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.colors.text2,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Полный отчёт — главное действие у завершённого осмотра, поэтому
/// выше повтора и в мягком акценте; залитый зелёный спорил бы
/// с «Новым заказом» внизу экрана.
class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.description_outlined, size: 14),
          label: const Text(
            'Посмотреть полный отчёт',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: context.colors.buySoft,
            foregroundColor: context.colors.modeBuy,
            side: BorderSide(color: context.colors.buyEdge),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
        ),
      ),
    );
  }
}

/// .again — «Осмотреть другую машину»: новый заказ с теми же адресом и ценой.
class _AgainButton extends StatelessWidget {
  const _AgainButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add, size: 13),
          label: const Text(
            'Осмотреть другую машину',
            style: TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.text2,
            side: BorderSide(color: context.colors.line),
            padding: const EdgeInsets.symmetric(vertical: 9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
        ),
      ),
    );
  }
}

/// .order-foot — аватар, строка про исполнителя, цена.
class OrderFoot extends StatelessWidget {
  const OrderFoot({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final executor = order.executor;
    final hasExecutor = executor != null;

    return Row(
      children: [
        if (hasExecutor)
          Avatar(initialsOf(executor.name))
        else
          // в макете: <div class="avatar" style="background:var(--bg-3);color:var(--text-3)">?</div>
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.bg3,
              shape: BoxShape.circle,
            ),
            child: Text(
              '?',
              style: context.text.avatar.copyWith(color: context.colors.text3),
            ),
          ),
        const SizedBox(width: 9),
        Expanded(
          child: hasExecutor
              ? Text.rich(
                  TextSpan(
                    text: executor.name,
                    style: TextStyle(
                      color: context.colors.text1,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      // «Максим К. · приедет» — выезд назначен, но ещё не начат
                      if (order.isInspection && order.status == OrderStatus.scheduled)
                        const TextSpan(text: ' · приедет'),
                    ],
                  ),
                  style: context.text.orderExec,
                )
              : Text(_responsesLabel(order.responses.length, order.isInspection),
                  style: context.text.orderExec),
        ),
        if (_price(order) != null)
          Text(
            _price(order)!,
            style: context.text.orderPrice.copyWith(fontFamily: AppTheme.monoFamily),
          ),
      ],
    );
  }

  /// Согласованный гонорар, иначе минимум из откликов, иначе — цена,
  /// которую назначил заказчик (она есть только у осмотра).
  String? _price(Order order) {
    if (order.price != null) return '${money(order.price!)} ₽';
    if (order.responses.isNotEmpty) {
      final min = order.responses
          .map((r) => r.proposedPrice)
          .reduce((a, b) => a < b ? a : b);
      return 'от ${money(min)} ₽';
    }
    if (order.askingPrice != null) return '${money(order.askingPrice!)} ₽';
    return null;
  }

  String _responsesLabel(int n, bool isInspection) {
    if (n == 0) return 'пока нет откликов';
    final mod10 = n % 10, mod100 = n % 100;
    final word = (mod10 == 1 && mod100 != 11)
        ? 'отклик'
        : (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
            ? 'отклика'
            : 'откликов';
    // у осмотра откликаются не подборщики, а исполнители — просто «3 отклика»
    return isInspection ? '$n $word' : '$n $word от подборщиков';
  }
}
