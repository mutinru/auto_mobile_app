/// Деньги и бюджет так, как их пишет макет: 2 400 000 ₽.
library;

/// Форматирование чисел как в макете: 2 400 000 ₽, 127 450 км.
String money(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Бюджет целиком: «2 000 000 — 2 400 000 ₽», «от …» (без потолка) или
/// «до …»; без обеих границ — null.
String? budgetRange(int? min, int? max) {
  if (min != null && max != null) return '${money(min)} — ${money(max)} ₽';
  if (min != null) return 'от ${money(min)} ₽';
  if (max != null) return 'до ${money(max)} ₽';
  return null;
}

/// Бюджет для мета-строк списков: «до max ₽», а без потолка («15 млн+») —
/// «от min ₽», чтобы такой заказ не остался без бюджета.
String? budgetShort(int? min, int? max) {
  if (max != null) return 'до ${money(max)} ₽';
  if (min != null) return 'от ${money(min)} ₽';
  return null;
}
