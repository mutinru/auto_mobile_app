import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/time_slot.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/price_box.dart';
import 'package:auto_podbor_mobile/widgets/repost_sheet.dart';

/// Ввод цены: сетка шага, набор с клавиатуры, удержание ±, перенос осмотра.
void main() {
  group('шаг', () {
    test('растёт с суммой', () {
      expect(PriceBox.stepFor(3500), 100);
      expect(PriceBox.stepFor(5000), 500);
      expect(PriceBox.stepFor(20000), 1000);
    });

    test('± ходят по сетке и честно переходят границы', () {
      expect(PriceBox.stepUp(4900), 5000);
      expect(PriceBox.stepUp(5000), 5500);
      expect(PriceBox.stepDown(5000), 4900);
      expect(PriceBox.stepDown(20000), 19500);
      expect(PriceBox.stepUp(20000), 21000);
      // некратная сумма — к ближайшей отметке, а не «+100 от 4 250»
      expect(PriceBox.stepUp(4250), 4300);
      expect(PriceBox.stepDown(4250), 4200);
    });

    test('проверка границ', () {
      expect(PriceBox.problem(500), isNull);
      expect(PriceBox.problem(499), 'Цена — от 500 ₽');
      expect(PriceBox.problem(1000001), 'Цена — до 1 000 000 ₽');
    });
  });

  group('PriceBox', () {
    Future<List<int>> pumpBox(WidgetTester tester, int start) async {
      final changes = <int>[];
      var value = start;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PriceBox(
                value: value,
                onChanged: (v) => setState(() {
                  value = v;
                  changes.add(v);
                }),
              ),
            ),
          ),
        ),
      );
      return changes;
    }

    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('сумму можно вписать: только цифры, с разрядами', (
      tester,
    ) async {
      final changes = await pumpBox(tester, 15000);
      await tester.enterText(find.byType(TextField), '48а00');
      await tester.pump();

      expect(fieldText(tester), '4 800');
      expect(changes.last, 4800);
    });

    testWidgets('на минимуме «−» не работает, на максимуме — «+»', (
      tester,
    ) async {
      var changes = await pumpBox(tester, 500);
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(changes, isEmpty);

      changes = await pumpBox(tester, 1000000);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(changes, isEmpty);
    });

    testWidgets('удержание «+» листает, отпускание останавливает', (
      tester,
    ) async {
      final changes = await pumpBox(tester, 3000);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.add)),
      );
      await tester.pump(
        const Duration(milliseconds: 600),
      ); // long press сработал
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump();

      expect(changes.last, greaterThan(3500));
      final stopped = changes.last;
      await tester.pump(const Duration(seconds: 1));
      expect(changes.last, stopped);
    });
  });

  group('перенос осмотра', () {
    const order = Order(
      id: 9,
      kind: OrderKind.inspection,
      status: OrderStatus.awaitingDecision,
      brand: 'Kia',
      model: 'Rio',
      askingPrice: 4000,
      timeSlot: TimeSlot.day,
      customer: UserSummary(id: 1, name: 'Андрей С.'),
    );

    Future<List<int?>> openRepost(WidgetTester tester) async {
      final sent = <int?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showRepostSheet(
                  context,
                  order: order,
                  now: () => DateTime(2026, 10, 31, 10),
                  onSubmit: (when, price) async => sent.add(price),
                ),
                child: const Text('открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();
      return sent;
    }

    Future<void> send(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Разместить'));
      await tester.tap(find.text('Разместить'));
      await tester.pumpAndSettle();
    }

    testWidgets('цена не менялась — не шлём', (tester) async {
      final sent = await openRepost(tester);
      expect(find.text('4 000'), findsOneWidget);
      await send(tester);
      expect(sent, [null]);
    });

    testWidgets('«+» меняет цену, «Вернуть прежнюю» отменяет', (tester) async {
      final sent = await openRepost(tester);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('4 100'), findsOneWidget);

      await tester.tap(find.text('Вернуть прежнюю цену · 4 000 ₽'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await send(tester);
      expect(sent, [4200]);
    });

    testWidgets('меньше 500 ₽ — ошибка, не отправляем', (tester) async {
      final sent = await openRepost(tester);
      await tester.enterText(find.byType(TextField).last, '400');
      await send(tester);
      expect(find.text('Цена — от 500 ₽'), findsOneWidget);
      expect(sent, isEmpty);
    });
  });
}
