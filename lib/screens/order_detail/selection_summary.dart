import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/order_status_card.dart';

/// Шапка подбора (ревью №16): статус, машина, города, пробег и бюджет,
/// требования чипами, комментарий заказчика.
class SelectionSummary extends StatelessWidget {
  const SelectionSummary({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrderStatusCard(order: order),
        const SizedBox(height: 14),
        Text(
          order.carTitle,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: c.text1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          [
            if (order.cities.isNotEmpty) order.cities.join(', '),
            if (order.mileageTo != null)
              'пробег до ${money(order.mileageTo!)} км',
            ?budgetRange(order.budgetMin, order.budgetMax),
          ].join(' · '),
          style: TextStyle(fontSize: 12.5, color: c.text2),
        ),
        if (order.requirements.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in order.requirements)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.bg1,
                    border: Border.all(color: c.chipEdge),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    r,
                    style: TextStyle(fontSize: 11.5, color: c.text2),
                  ),
                ),
            ],
          ),
        ],
        if (order.comment != null && order.comment!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            order.comment!,
            style: TextStyle(fontSize: 13, color: c.text2),
          ),
        ],
      ],
    );
  }
}
