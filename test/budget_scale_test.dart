import 'package:flutter_test/flutter_test.dart';
import 'package:auto_podbor_mobile/widgets/app_ui.dart';
import 'package:auto_podbor_mobile/widgets/budget_scale.dart';

void main() {
  group('BudgetScale', () {
    test('отметки растут от 150 тыс. до 15 млн', () {
      final s = BudgetScale.stops;
      expect(s.first, 150000);
      expect(s.last, 15000000);
      for (var i = 1; i < s.length; i++) {
        expect(s[i], greaterThan(s[i - 1]));
      }
    });

    test('шаг внизу мелкий, вверху крупный', () {
      final s = BudgetScale.stops;
      expect(s[1] - s[0], 50000);
      expect(s.last - s[s.length - 2], 1000000);
    });

    test('последняя отметка верхней ручки — без потолка', () {
      expect(BudgetScale.maxAt(BudgetScale.openIndex), isNull);
      expect(BudgetScale.minAt(BudgetScale.openIndex), 15000000);
      expect(BudgetScale.maxAt(BudgetScale.openIndex - 1), 14000000);
    });

    test('indexOf находит ближайшую отметку', () {
      expect(BudgetScale.stops[BudgetScale.indexOf(1800000)], 1800000);
      expect(BudgetScale.stops[BudgetScale.indexOf(3100000)], 3000000);
      expect(BudgetScale.indexOf(0), 0);
      expect(BudgetScale.indexOf(99000000), BudgetScale.openIndex);
    });
  });

  group('формат бюджета', () {
    test('budgetRange', () {
      expect(budgetRange(2000000, 2400000), '2 000 000 — 2 400 000 ₽');
      expect(budgetRange(15000000, null), 'от 15 000 000 ₽');
      expect(budgetRange(null, 2400000), 'до 2 400 000 ₽');
      expect(budgetRange(null, null), isNull);
    });

    test('budgetShort: без потолка — «от min»', () {
      expect(budgetShort(2000000, 2400000), 'до 2 400 000 ₽');
      expect(budgetShort(15000000, null), 'от 15 000 000 ₽');
      expect(budgetShort(null, null), isNull);
    });
  });
}
