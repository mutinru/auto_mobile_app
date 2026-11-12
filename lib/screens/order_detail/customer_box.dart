import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/phone_contact.dart';

/// Заказчик подбора для исполнителя: имя и телефон с «Позвонить» — номер
/// сервер открывает с выбора исполнителя.
class CustomerBox extends StatelessWidget {
  const CustomerBox({super.key, required this.order, required this.phone});

  final Order order;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: c.bg1,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Avatar(
                initialsOf(order.customer.name),
                size: 36,
                url: order.customer.avatarUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  order.customer.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text1,
                  ),
                ),
              ),
            ],
          ),
          PhoneCallRow(label: 'Телефон заказчика', phone: phone),
        ],
      ),
    );
  }
}
