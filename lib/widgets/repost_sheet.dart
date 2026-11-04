import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/time_slot.dart';
import 'api_error.dart';
import 'app_sheet.dart';
import 'app_ui.dart';
import 'inspection_when_picker.dart';
import 'price_box.dart';

/// «Разместить заново» для осмотра, который ждёт решения заказчика: новая
/// дата обязательна (прошлая уже прошла), время и цену можно поменять.
/// Отправка передаётся снаружи — лист проверяется без сети. [now] — для тестов.
Future<void> showRepostSheet(
  BuildContext context, {
  required Order order,
  required Future<void> Function(InspectionWhen when, int? askingPrice)
  onSubmit,
  DateTime Function()? now,
}) {
  return showAppSheet<void>(
    context,
    (context) => _RepostSheet(order: order, onSubmit: onSubmit, now: now),
  );
}

class _RepostSheet extends StatefulWidget {
  const _RepostSheet({required this.order, required this.onSubmit, this.now});

  final Order order;
  final Future<void> Function(InspectionWhen when, int? askingPrice) onSubmit;
  final DateTime Function()? now;

  @override
  State<_RepostSheet> createState() => _RepostSheetState();
}

class _RepostSheetState extends State<_RepostSheet> {
  late InspectionWhen _when;

  /// Прежняя цена заказа: не изменилась — не шлём, сервер её оставит.
  late final int _previous = widget.order.askingPrice ?? 3500;
  late int _price = _previous;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = (widget.now ?? DateTime.now)();
    // прежний слот мог на сегодня уже пройти — подгоняем
    _when = fitWhen(
      InspectionWhen(
        date: firstInspectionDay(now),
        slot: widget.order.timeSlot ?? TimeSlot.day,
        exactTime: parseInspectTime(widget.order.inspectTime),
      ),
      now,
    );
  }

  Future<void> _send() async {
    final priceProblem = PriceBox.problem(_price);
    if (priceProblem != null) return setState(() => _error = priceProblem);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // цена не изменилась — не шлём, сервер оставит прежнюю
      await widget.onSubmit(
        _when,
        _price == widget.order.askingPrice ? null : _price,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Разместить заново',
      subtitle:
          'Выберите новый день осмотра. Прежние отклики были под старую '
          'дату — исполнители получат уведомление и откликнутся заново.',
      children: [
        InspectionWhenPicker(
          value: _when,
          now: widget.now,
          onChanged: (when) => setState(() => _when = when),
        ),
        const SizedBox(height: 14),
        const SectionHead('Ваша цена'),
        PriceBox(value: _price, onChanged: (v) => setState(() => _price = v)),
        if (_price != _previous)
          PriceResetLink(
            label: 'Вернуть прежнюю цену · ${money(_previous)} ₽',
            onTap: () => setState(() => _price = _previous),
          ),
        const SizedBox(height: 10),
        SheetError(_error),
        CtaPrimary(
          label: 'Разместить',
          loading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
