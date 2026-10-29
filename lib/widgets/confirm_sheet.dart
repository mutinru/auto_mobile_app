import 'package:flutter/material.dart';

import 'app_sheet.dart';
import 'app_ui.dart';

/// Подтверждение необратимого действия: «Я оплатил», «Оплату получил»,
/// «Отказаться». Возвращает true, только если нажата основная кнопка.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String text,
  required String confirmLabel,
  String cancelLabel = 'Отмена',
}) async {
  final result = await showAppSheet<bool>(
    context,
    (context) => SheetFrame(
      title: title,
      subtitle: text,
      children: [
        CtaPrimary(label: confirmLabel, onPressed: () => Navigator.of(context).pop(true)),
        CtaGhost(label: cancelLabel, onPressed: () => Navigator.of(context).pop(false)),
      ],
    ),
  );
  return result ?? false;
}
