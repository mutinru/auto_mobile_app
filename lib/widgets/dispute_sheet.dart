import 'package:flutter/material.dart';

import 'api_error.dart';
import 'app_sheet.dart';
import 'app_ui.dart';

/// Открыть спор об оплате: причина обязательна (до 2000 символов, как
/// валидация бекенда). Отправка передаётся снаружи — лист проверяется без сети.
Future<void> showDisputeSheet(
  BuildContext context, {
  required Future<void> Function(String reason) onSubmit,
}) {
  return showAppSheet<void>(context, (context) => _DisputeSheet(onSubmit: onSubmit));
}

class _DisputeSheet extends StatefulWidget {
  const _DisputeSheet({required this.onSubmit});

  final Future<void> Function(String reason) onSubmit;

  @override
  State<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<_DisputeSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await widget.onSubmit(_controller.text.trim());
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
      title: 'Открыть спор',
      subtitle: 'Опишите, что пошло не так с оплатой. Поддержка свяжется '
          'с обеими сторонами и разберётся.',
      children: [
        FieldBoxInput(
          label: 'Причина',
          controller: _controller,
          hint: 'Например: перевёл 3 500 ₽ вчера, подтверждения нет',
          maxLines: 4,
          maxLength: 2000,
          autofocus: true,
        ),
        SheetError(_error),
        CtaPrimary(
          label: 'Открыть спор',
          loading: _sending,
          onPressed: _controller.text.trim().isEmpty ? null : _send,
        ),
      ],
    );
  }
}
