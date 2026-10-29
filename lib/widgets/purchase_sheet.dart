import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_car.dart';
import '../theme/app_colors.dart';
import 'app_sheet.dart';
import 'app_ui.dart';

/// «Зафиксировать покупку»: заказчик выбирает купленного кандидата.
/// Возвращает его id или null, если лист закрыли. Остальные кандидаты
/// сервер сам пометит как отклонённые, а заказ закроет.
Future<int?> showPurchaseSheet(BuildContext context, {required Order order}) {
  return showAppSheet<int>(context, (_) => _PurchaseSheet(order: order));
}

class _PurchaseSheet extends StatefulWidget {
  const _PurchaseSheet({required this.order});
  final Order order;

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  int? _carId;

  @override
  void initState() {
    super.initState();
    // кандидат один — выбирать не из чего
    if (widget.order.cars.length == 1) _carId = widget.order.cars.single.id;
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Какую машину купили?',
      subtitle: 'Заказ закроется, и вы сможете оценить подборщика. '
          'Отменить это нельзя.',
      children: [
        for (final car in widget.order.cars)
          _CarOption(
            car: car,
            selected: _carId == car.id,
            onTap: () => setState(() => _carId = car.id),
          ),
        const SizedBox(height: 6),
        CtaPrimary(
          label: 'Зафиксировать покупку',
          onPressed: _carId == null ? null : () => Navigator.of(context).pop(_carId),
        ),
        CtaGhost(label: 'Отмена', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _CarOption extends StatelessWidget {
  const _CarOption({required this.car, required this.selected, required this.onTap});

  final OrderCar car;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.statusDone;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.10) : context.colors.bg1,
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.55) : context.colors.line,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: selected ? accent : context.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'VIN ${car.vinMasked}',
                      style: TextStyle(fontSize: 11.5, color: context.colors.text3),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check, size: 16, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
