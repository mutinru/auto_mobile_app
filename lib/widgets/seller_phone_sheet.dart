import 'package:flutter/material.dart';

import '../data/api_exception.dart';
import '../models/order_car.dart';
import '../theme/app_colors.dart';
import 'api_error.dart';
import 'app_sheet.dart';
import 'app_ui.dart';
import 'phone_input.dart';

/// Пометка под телефоном продавца кандидата: номер — заметка подборщика.
const sellerPhoneNote =
    'Номер видите только вы — заказчику он не показывается. Пригодится, '
    'если заказчик выберет эту машину.';

/// Добавить, поменять или стереть телефон продавца кандидата. [onSave]
/// отправляет номер (+7XXXXXXXXXX или null) на сервер; лист закрывается
/// с машиной из ответа, ошибка 422 — у поля.
Future<OrderCar?> showSellerPhoneSheet(
  BuildContext context, {
  required OrderCar car,
  required Future<OrderCar> Function(String? phone) onSave,
}) {
  return showAppSheet<OrderCar>(
    context,
    (context) => _SellerPhoneSheet(car: car, onSave: onSave),
  );
}

class _SellerPhoneSheet extends StatefulWidget {
  const _SellerPhoneSheet({required this.car, required this.onSave});

  final OrderCar car;
  final Future<OrderCar> Function(String? phone) onSave;

  @override
  State<_SellerPhoneSheet> createState() => _SellerPhoneSheetState();
}

class _SellerPhoneSheetState extends State<_SellerPhoneSheet> {
  late final _controller = TextEditingController(
    text: phoneMaskText(widget.car.sellerPhone ?? ''),
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String? phone) async {
    final problem = phone == null ? null : sellerPhoneProblem(_controller.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final car = await widget.onSave(phone);
      if (mounted) Navigator.of(context).pop(car);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.fieldErrors['seller_phone'] ?? apiErrorText(e),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final had = widget.car.sellerPhone != null;
    return SheetFrame(
      title: 'Телефон продавца',
      subtitle: widget.car.title,
      children: [
        PhoneField(controller: _controller, autofocus: true),
        FieldError(_error),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 14),
          child: Text(sellerPhoneNote, style: context.text.fieldNote),
        ),
        CtaPrimary(
          label: 'Сохранить',
          loading: _saving,
          onPressed: _saving
              ? null
              : () => _save(phoneFromMask(_controller.text)),
        ),
        if (had) ...[
          const SizedBox(height: 8),
          CtaGhost(
            label: 'Удалить номер',
            onPressed: _saving ? null : () => _save(null),
          ),
        ],
      ],
    );
  }
}
