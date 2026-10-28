import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_colors.dart';
import 'app_ui.dart';

/// Лист отклика на свободный заказ: цена и сообщение. Возвращает через
/// Navigator.pop пару (цена, сообщение?) или null, если лист закрыли.
/// Общий для экрана-списка «Заказы рядом» и карты.
class RespondSheet extends StatefulWidget {
  const RespondSheet({super.key, required this.order});
  final Order order;

  @override
  State<RespondSheet> createState() => RespondSheetState();
}

class RespondSheetState extends State<RespondSheet> {
  final _priceController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.order.carTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.colors.text1,
            ),
          ),
          if (widget.order.askingPrice != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Заказчик назвал ${money(widget.order.askingPrice!)} ₽',
                style: TextStyle(fontSize: 11.5, color: context.colors.text2),
              ),
            ),
          const SizedBox(height: 14),
          FieldBoxInput(
            label: 'Ваша цена',
            controller: _priceController,
            hint: widget.order.askingPrice != null
                ? money(widget.order.askingPrice!)
                : '15 000',
            mono: true,
            unit: '₽',
            keyboardType: TextInputType.number,
          ),
          FieldBoxInput(
            label: 'Сообщение',
            controller: _messageController,
            hint: 'Необязательно',
            maxLines: 2,
            minHeight: 56,
          ),
          const SizedBox(height: 6),
          CtaPrimary(
            label: 'Отправить отклик',
            onPressed: () {
              final price = int.tryParse(_priceController.text.replaceAll(' ', ''));
              if (price == null) return;
              Navigator.of(context).pop((
                price,
                _messageController.text.trim().isEmpty
                    ? null
                    : _messageController.text.trim(),
              ));
            },
          ),
        ],
      ),
    );
  }
}
