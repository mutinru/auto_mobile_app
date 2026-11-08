import 'package:flutter/material.dart';

import '../data/api_exception.dart';
import '../models/order.dart';
import '../models/payout.dart';
import 'api_error.dart';
import 'app_sheet.dart';
import 'app_ui.dart';
import 'payout_fields.dart';
import 'phone_contact.dart';
import 'price_box.dart';

/// Отклик на свободный заказ. true — отклик отправлен, null — лист закрыли.
///
/// Разовый осмотр оплачивается напрямую, поэтому при первом отклике на
/// него ([requiresPayout]) лист спрашивает реквизиты: сервер сохранит их в
/// профиль и дальше не спросит. Отправка — внутри листа, чтобы ошибки 422
/// по полям показать у полей и не терять ввод.
Future<bool?> showRespondSheet(
  BuildContext context, {
  required Order order,
  required Future<void> Function(int price, String? message, Payout? payout)
  onSubmit,
  bool requiresPayout = false,
}) {
  return showAppSheet<bool>(
    context,
    (context) => RespondSheet(
      order: order,
      onSubmit: onSubmit,
      requiresPayout: requiresPayout,
    ),
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
  final Future<void> Function(int price, String? message, Payout? payout)
  onSubmit;
  final bool requiresPayout;

  @override
  State<RespondSheet> createState() => RespondSheetState();
}

class RespondSheetState extends State<RespondSheet> {
  /// Старт для подбора — у него нет цены заказчика.
  static const _defaultPrice = 15000;

  late int _price;
  final _messageController = TextEditingController();
  final _payout = PayoutFormController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _price = widget.order.askingPrice ?? _defaultPrice;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _payout.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final priceProblem = PriceBox.problem(_price);
    if (priceProblem != null) return setState(() => _error = priceProblem);
    final payout = widget.requiresPayout ? _payout.validate() : null;
    setState(() => _error = null);
    if (widget.requiresPayout && payout == null) return;

    final message = _messageController.text.trim();
    setState(() => _sending = true);
    try {
      await widget.onSubmit(_price, message.isEmpty ? null : message, payout);
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
        const SectionHead('Ваша цена'),
        PriceBox(value: _price, onChanged: (v) => setState(() => _price = v)),
        if (asking != null && _price != asking)
          PriceResetLink(
            label: 'Вернуть цену заказчика · ${money(asking)} ₽',
            onTap: () => setState(() => _price = asking),
          ),
        const SizedBox(height: 10),
        FieldBoxInput(
          label: 'Сообщение',
          controller: _messageController,
          hint: 'Необязательно',
          maxLines: 2,
          maxLength: 1000,
          minHeight: 56,
        ),
        // подбор: номера открываются сторонам с выбора исполнителя
        if (!widget.order.isInspection) ...[
          const SizedBox(height: 4),
          const PhoneExchangeNote(
            'Если заказчик выберет вас, вы увидите телефоны друг друга — '
            'сможете созвониться напрямую.',
          ),
        ],
        if (widget.requiresPayout) ...[
          const SizedBox(height: 8),
          const SectionHead('Куда заказчик переведёт оплату'),
          PayoutFields(controller: _payout),
          const SizedBox(height: 14),
        ],
        SheetError(_error),
        const SizedBox(height: 6),
        CtaPrimary(
          label: 'Отправить отклик',
          loading: _sending,
          onPressed: _send,
        ),
      ],
    );
  }
}
