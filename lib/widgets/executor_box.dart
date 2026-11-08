import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';
import 'executor_stats.dart';
import 'phone_contact.dart';

/// Назначенный исполнитель заказа: имя, рейтинг, цена. У осмотра ещё
/// телефон продавца — бекенд отдаёт его только заказчику и выбранному
/// исполнителю, у подбора его нет. У подбора заказчику — телефон самого
/// исполнителя с «Позвонить» ([phone]).
class ExecutorBox extends StatelessWidget {
  const ExecutorBox({
    super.key,
    required this.order,
    this.onShowReviews,
    this.phone,
  });

  final Order order;
  final VoidCallback? onShowReviews;

  /// Телефон исполнителя для заказчика (Order.counterpartPhone); null —
  /// строки нет. Исполнителю, который смотрит сам на себя, не передаётся.
  final String? phone;

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
          if (phone case final phone? when phone.isNotEmpty)
            PhoneCallRow(label: 'Телефон исполнителя', phone: phone),
        ],
      ),
    );
  }
}
