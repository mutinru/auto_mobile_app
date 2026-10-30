import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/order.dart';
import '../models/time_slot.dart';
import 'api_error.dart';
import 'app_sheet.dart';
import 'app_ui.dart';
import 'inspection_when_picker.dart';

/// «Разместить заново» для осмотра, который ждёт решения заказчика: новая
/// дата обязательна (прошлая уже прошла), время и цену можно поменять.
/// Отправка передаётся снаружи — лист проверяется без сети. [now] — для тестов.
Future<void> showRepostSheet(
  BuildContext context, {
  required Order order,
  required Future<void> Function(InspectionWhen when, int? askingPrice) onSubmit,
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
  late final _price = TextEditingController(text: '${widget.order.askingPrice ?? ''}');
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _when = InspectionWhen(
      date: firstInspectionDay((widget.now ?? DateTime.now)()),
      slot: widget.order.timeSlot ?? TimeSlot.day,
      exactTime: parseInspectTime(widget.order.inspectTime),
    );
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _price.text.replaceAll(' ', '');
    final price = int.tryParse(text);
    if (text.isNotEmpty && price == null) {
      setState(() => _error = 'Цена — числом, в рублях');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // цена не изменилась — не шлём, сервер оставит прежнюю
      await widget.onSubmit(_when, price == widget.order.askingPrice ? null : price);
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
      subtitle: 'Выберите новый день осмотра. Прежние отклики были под старую '
          'дату — исполнители получат уведомление и откликнутся заново.',
      children: [
        InspectionWhenPicker(
          value: _when,
          now: widget.now,
          onChanged: (when) => setState(() => _when = when),
        ),
        const SizedBox(height: 14),
        FieldBoxInput(
          label: 'Ваша цена',
          controller: _price,
          mono: true,
          unit: '₽',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
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
