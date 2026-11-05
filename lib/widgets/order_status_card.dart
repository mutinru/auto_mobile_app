import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_status.dart';
import '../theme/app_colors.dart';

/// Статус-блок в шапке экрана подбора: этап крупно, под ним прогресс
/// осмотров (`Order.statusDetail`). В списках остаётся `OrderStatusPill`.
class OrderStatusCard extends StatelessWidget {
  const OrderStatusCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final status = order.shownStatus;
    final accent = status.color(c);
    // Нейтральные статусы («ждёт исполнителя», «отменён») — на сером фоне,
    // как .pill без модификатора в макете.
    final tinted = status.pillColor(c) != null;
    final title = status.labelFor(order.kind);
    final detail = order.statusDetail;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tinted ? accent.withValues(alpha: 0.12) : c.bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tinted ? accent.withValues(alpha: 0.35) : c.line,
        ),
      ),
      child: Row(
        crossAxisAlignment: detail == null
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: detail == null ? 0 : 6),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title[0].toUpperCase() + title.substring(1),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.text1,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(fontSize: 13, color: c.text2),
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
