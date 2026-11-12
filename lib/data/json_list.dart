import 'package:flutter/foundation.dart';

/// Разобрать список с сервера по элементу (ревью №35): битый элемент —
/// неожиданный null, незнакомое значение — пропускается с записью в лог,
/// а не роняет весь экран. «Мои заказы» покажут 49 нормальных заказов, а не
/// ошибку из-за одного. [what] — что за элементы, для лога.
///
/// Не для деталей осмотра и каталога дефектов: молча потерянная деталь
/// дала бы неполный отчёт — там ошибка остаётся ошибкой.
List<T> parseList<T>(
  Object? raw,
  T Function(Map<String, dynamic> json) parse, {
  required String what,
}) {
  if (raw is! List) {
    debugPrint('Список «$what» не пришёл: ${raw.runtimeType}');
    return [];
  }
  final items = <T>[];
  for (final item in raw) {
    try {
      items.add(parse(item as Map<String, dynamic>));
    } catch (e) {
      final id = item is Map ? item['id'] : null;
      debugPrint('Пропущен элемент «$what» (id $id): $e');
    }
  }
  return items;
}
