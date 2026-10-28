import 'package:flutter/material.dart';

import '../models/order_status.dart';
import '../theme/app_colors.dart';

/// Соответствует .pill/.pill.search/.pill.check/.pill.done из макета.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: status.color(context.colors).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: status.color(context.colors),
        ),
      ),
    );
  }
}
