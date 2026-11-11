import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/inspection_outcome.dart';
import '../models/order_car.dart';
import '../theme/app_colors.dart';
import '../util/ru_date.dart';
import 'app_sheet.dart';
import 'app_ui.dart';

/// Выбор купленного кандидата подбора. Возвращает id машины или null, если
/// лист закрыли. Один лист на три случая:
/// - заказчик фиксирует покупку ([showPurchaseSheet]) — остальные кандидаты
///   сервер пометит отклонёнными и закроет заказ;
/// - исполнитель сообщает о покупке ([showReportPurchaseSheet]);
/// - заказчик меняет купленную машину ([showChangePurchaseSheet]).
/// Предлагаются только кандидаты с осмотром — без него исхода у машины нет.
Future<int?> showPurchaseSheet(BuildContext context, {required Order order}) {
  return _show(
    context,
    title: 'Какую машину купили?',
    subtitle:
        'Заказ закроется, и вы сможете оценить подборщика. '
        'Выбор можно изменить в течение суток.',
    confirmLabel: 'Зафиксировать покупку',
    cars: [
      for (final car in order.cars)
        if (car.inspectionId != null) car,
    ],
  );
}

/// Исполнитель: какую машину купил заказчик. Только кандидаты с вердиктом —
/// без отчёта заказчику нечего подтверждать (сервер ответит 422).
Future<int?> showReportPurchaseSheet(
  BuildContext context, {
  required Order order,
}) {
  return _show(
    context,
    title: 'Какую машину купил заказчик?',
    subtitle:
        'Заказчик получит уведомление и подтвердит покупку — '
        'после этого заказ закроется.',
    confirmLabel: 'Сообщить заказчику',
    cars: [
      for (final car in order.cars)
        if (car.inspectionStatus == 'completed' && car.verdict != null) car,
    ],
  );
}

/// Заказчик: купили другую машину. Открывается с текущим выбором; та же
/// машина — не изменение, кнопка неактивна.
Future<int?> showChangePurchaseSheet(
  BuildContext context, {
  required Order order,
}) {
  final current = order.cars
      .where((c) => c.inspectionOutcome == InspectionOutcome.purchased)
      .firstOrNull;
  final until = order.purchaseEditableUntil;
  return _show(
    context,
    title: 'Какую машину купили?',
    subtitle: until != null
        ? 'Изменить выбор можно до ${momentLabel(until)}.'
        : 'Выберите купленную машину.',
    confirmLabel: 'Сохранить',
    cars: [
      for (final car in order.cars)
        if (car.inspectionId != null) car,
    ],
    initial: current?.id,
  );
}

Future<int?> _show(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String confirmLabel,
  required List<OrderCar> cars,
  int? initial,
}) {
  return showAppSheet<int>(
    context,
    (_) => _PurchaseSheet(
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
      cars: cars,
      initial: initial,
    ),
  );
}

class _PurchaseSheet extends StatefulWidget {
  const _PurchaseSheet({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.cars,
    this.initial,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final List<OrderCar> cars;

  /// Текущий выбор (смена покупки) — подтвердить его же нельзя.
  final int? initial;

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  int? _carId;

  @override
  void initState() {
    super.initState();
    _carId = widget.initial;
    // кандидат один — выбирать не из чего
    if (_carId == null && widget.cars.length == 1) {
      _carId = widget.cars.single.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _carId != null && _carId != widget.initial;
    return SheetFrame(
      title: widget.title,
      subtitle: widget.subtitle,
      children: [
        for (final car in widget.cars)
          _CarOption(
            car: car,
            selected: _carId == car.id,
            onTap: () => setState(() => _carId = car.id),
          ),
        const SizedBox(height: 6),
        CtaPrimary(
          label: widget.confirmLabel,
          onPressed: canConfirm
              ? () => Navigator.of(context).pop(_carId)
              : null,
        ),
        CtaGhost(label: 'Отмена', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _CarOption extends StatelessWidget {
  const _CarOption({
    required this.car,
    required this.selected,
    required this.onTap,
  });

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
            color: selected
                ? accent.withValues(alpha: 0.10)
                : context.colors.bg1,
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.55)
                  : context.colors.line,
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
                        color: selected
                            ? context.colors.doneText
                            : context.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'VIN ${car.vinMasked}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.text3,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check, size: 16, color: context.colors.doneText),
            ],
          ),
        ),
      ),
    );
  }
}
