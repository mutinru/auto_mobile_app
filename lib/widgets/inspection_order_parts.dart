import 'package:flutter/material.dart';

import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/ru_date.dart';
import 'app_ui.dart';

/// Общие куски детали разового осмотра — у заказчика
/// ([InspectionOrderDetailScreen]) и у исполнителя ([AssignedInspectionScreen]).

/// .summary — дата, адрес, пробег и объявление, внизу цена. Подпись цены
/// разная: заказчику — «Ваша цена», исполнителю — «Ваш гонорар».
class InspectionOrderSummary extends StatelessWidget {
  const InspectionOrderSummary({
    super.key,
    required this.order,
    required this.priceLabel,
    required this.price,
  });

  final Order order;
  final String priceLabel;
  final int? price;

  @override
  Widget build(BuildContext context) {
    final listing = order.listingUrl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.line),
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
          if (order.mileageTo != null)
            _SummaryRow(
              icon: Icons.speed_outlined,
              text: '${money(order.mileageTo!)} км',
            ),
          // ссылка — просто текст: разбор объявления не делаем
          if (listing != null && listing.isNotEmpty)
            _SummaryRow(icon: Icons.link, text: listing),
          if (price != null) ...[
            const SizedBox(height: 11),
            Container(height: 1, color: context.colors.line),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Text(
                    priceLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.colors.text2,
                    ),
                  ),
                ),
                Text(
                  '${money(price!)} ₽',
                  style: TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
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

/// .summary-row
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.text,
    this.strong = false,
  });

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
            child: Icon(icon, size: 15, color: context.colors.text3),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                color: strong ? context.colors.text1 : context.colors.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Вердикт с комментарием — то, ради чего заказ и делался.
class InspectionVerdictBox extends StatelessWidget {
  const InspectionVerdictBox({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final verdict = order.verdict!;
    final comment = order.cars.first.verdictComment;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(
          color: verdict.color(context.colors).withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: verdict.color(context.colors).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              verdict.icon,
              size: 15,
              color: verdict.color(context.colors),
            ),
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
                    color: verdict.color(context.colors),
                  ),
                ),
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    comment,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.colors.text2,
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
