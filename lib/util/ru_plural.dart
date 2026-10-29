/// Склонение по числу: plural(3, 'отзыв', 'отзыва', 'отзывов') → 'отзыва'.
String plural(int n, String one, String few, String many) {
  final mod100 = n.abs() % 100;
  final mod10 = mod100 % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

/// «12 отзывов», «1 заказ».
String counted(int n, String one, String few, String many) =>
    '$n ${plural(n, one, few, many)}';
