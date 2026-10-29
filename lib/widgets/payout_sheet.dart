import 'package:flutter/material.dart';

import '../data/api_exception.dart';
import '../models/payout.dart';
import 'api_error.dart';
import 'app_sheet.dart';
import 'app_ui.dart';
import 'payout_fields.dart';

/// Реквизиты для выплат из профиля. Сохранение передаётся снаружи (в
/// приложении — AuthService.updatePayout), как у showEditNameSheet.
Future<void> showPayoutSheet(
  BuildContext context, {
  Payout? initial,
  required Future<void> Function(Payout payout) onSave,
}) {
  return showAppSheet<void>(context, (context) => _PayoutSheet(initial: initial, onSave: onSave));
}

class _PayoutSheet extends StatefulWidget {
  const _PayoutSheet({required this.initial, required this.onSave});

  final Payout? initial;
  final Future<void> Function(Payout payout) onSave;

  @override
  State<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends State<_PayoutSheet> {
  late final _form = PayoutFormController(initial: widget.initial);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final payout = _form.validate();
    if (payout == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(payout);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      _form.setServerErrors(e.fieldErrors);
      // ошибка не по полям реквизитов — общей строкой
      if (_form.errors.isEmpty) setState(() => _error = apiErrorText(e));
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: 'Реквизиты для выплат',
      subtitle: 'Заказчик разового осмотра переводит оплату вам напрямую — '
          'на карту или по СБП.',
      children: [
        PayoutFields(controller: _form),
        const SizedBox(height: 14),
        SheetError(_error),
        CtaPrimary(label: 'Сохранить', loading: _saving, onPressed: _save),
      ],
    );
  }
}
