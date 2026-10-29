import 'package:flutter/material.dart';

import '../data/api_exception.dart';
import '../models/order.dart';
import '../models/payout.dart';
import 'api_error.dart';
import 'app_sheet.dart';
import 'app_ui.dart';
import 'payout_fields.dart';

/// Отклик на свободный заказ. true — отклик отправлен, null — лист закрыли.
///
/// Разовый осмотр оплачивается напрямую, поэтому при первом отклике на
/// него ([requiresPayout]) лист спрашивает реквизиты: сервер сохранит их в
/// профиль и дальше не спросит. Отправка — внутри листа, чтобы ошибки 422
/// по полям показать у полей и не терять ввод.
Future<bool?> showRespondSheet(
  BuildContext context, {
  required Order order,
  required Future<void> Function(int price, String? message, Payout? payout) onSubmit,
  bool requiresPayout = false,
}) {
  return showAppSheet<bool>(
    context,
    (context) => RespondSheet(order: order, onSubmit: onSubmit, requiresPayout: requiresPayout),
  );
}

/// Общий для экрана-списка «Заказы рядом» и карты.
class RespondSheet extends StatefulWidget {
  const RespondSheet({
    super.key,
    required this.order,
    required this.onSubmit,
    this.requiresPayout = false,
  });

  final Order order;
  final Future<void> Function(int price, String? message, Payout? payout) onSubmit;
  final bool requiresPayout;

  @override
  State<RespondSheet> createState() => RespondSheetState();
}

class RespondSheetState extends State<RespondSheet> {
  final _priceController = TextEditingController();
  final _messageController = TextEditingController();
  final _payout = PayoutFormController();
  bool _sending = false;
  String? _priceError;
  String? _error;

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    _payout.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final price = int.tryParse(_priceController.text.replaceAll(' ', ''));
    final payout = widget.requiresPayout ? _payout.validate() : null;
    setState(() {
      _priceError = price == null ? 'Укажите цену числом' : null;
      _error = null;
    });
    if (price == null || (widget.requiresPayout && payout == null)) return;

    final message = _messageController.text.trim();
    setState(() => _sending = true);
    try {
      await widget.onSubmit(price, message.isEmpty ? null : message, payout);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _payout.setServerErrors(e.fieldErrors);
      // ошибка не по реквизитам (заказ уже занят, 403 верификации) — строкой
      if (_payout.errors.isEmpty) setState(() => _error = apiErrorText(e));
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asking = widget.order.askingPrice;
    return SheetFrame(
      title: widget.order.carTitle,
      subtitle: asking != null ? 'Заказчик назвал ${money(asking)} ₽' : null,
      children: [
        FieldBoxInput(
          label: 'Ваша цена',
          controller: _priceController,
          hint: asking != null ? money(asking) : '15 000',
          mono: true,
          unit: '₽',
          keyboardType: TextInputType.number,
        ),
        SheetError(_priceError),
        FieldBoxInput(
          label: 'Сообщение',
          controller: _messageController,
          hint: 'Необязательно',
          maxLines: 2,
          minHeight: 56,
        ),
        if (widget.requiresPayout) ...[
          const SizedBox(height: 8),
          const SectionHead('Куда заказчик переведёт оплату'),
          PayoutFields(controller: _payout),
          const SizedBox(height: 14),
        ],
        SheetError(_error),
        const SizedBox(height: 6),
        CtaPrimary(label: 'Отправить отклик', loading: _sending, onPressed: _send),
      ],
    );
  }
}
