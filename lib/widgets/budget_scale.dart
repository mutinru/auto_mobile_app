/// Нелинейная шкала бюджета для слайдера «Что искать»: мелкий шаг внизу,
/// крупный вверху — иначе до 15 млн пальцем не выставить 800 тыс.
/// Слайдер ходит по индексам отметок; последняя отметка — «15 млн+»,
/// то есть бюджет без потолка (`budget_max = null`).
class BudgetScale {
  BudgetScale._();

  static final List<int> stops = _buildStops();

  /// Индекс открытой верхней отметки «15 млн+».
  static int get openIndex => stops.length - 1;

  static List<int> _buildStops() {
    final out = <int>[];
    void range(int from, int to, int step) {
      for (var v = from; v < to; v += step) {
        out.add(v);
      }
    }

    range(150000, 1000000, 50000);
    range(1000000, 3000000, 100000);
    range(3000000, 5000000, 250000);
    range(5000000, 10000000, 500000);
    range(10000000, 15000001, 1000000);
    return out;
  }

  /// Сумма для нижней ручки: у неё «15 млн+» — это просто «от 15 млн».
  static int minAt(int index) => stops[index];

  /// Сумма для верхней ручки: на последней отметке потолка нет — null.
  static int? maxAt(int index) => index >= openIndex ? null : stops[index];

  /// Ближайшая отметка к сумме (для начального положения ручек).
  static int indexOf(int value) {
    var best = 0;
    for (var i = 1; i < stops.length; i++) {
      if ((stops[i] - value).abs() < (stops[best] - value).abs()) best = i;
    }
    return best;
  }
}
