import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/screens/new_inspection_screen.dart';
import 'package:auto_podbor_mobile/screens/new_order_screen.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/app_ui.dart';

import 'support/stores.dart';

/// Поля «Что искать»: числа без мусора, год в границах сервера, город обязателен.
void main() {
  test('yearProblem — те же границы, что на бекенде', () {
    final now = DateTime(2026, 10, 31);
    expect(yearProblem(1990, now: now), isNull);
    expect(yearProblem(2027, now: now), isNull);
    expect(yearProblem(1989, now: now), 'Год — от 1990 до 2027');
    expect(yearProblem(2028, now: now), isNotNull);
  });

  test('mileageProblem — потолок сервера, 2 000 000 км', () {
    expect(mileageProblem(0), isNull);
    expect(mileageProblem(2000000), isNull);
    expect(mileageProblem(2000001), 'Пробег — не больше 2 000 000 км');
  });

  Future<void> openForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: NewOrderScreen(
          store: mockStore(
            orders: MockOrderRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickCamry(WidgetTester tester) async {
    await tester.tap(find.text('Выбрать марку и модель'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toyota').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camry'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Разместить заказ'));
    await tester.tap(find.text('Разместить заказ'));
    await tester.pump();
  }

  testWidgets('в год и пробег проходят только цифры', (tester) async {
    await openForm(tester);
    // поля формы по порядку: год, пробег, комментарий
    await tester.enterText(find.byType(TextField).at(0), '20a1.8');
    await tester.enterText(find.byType(TextField).at(1), '120.000 км');
    await tester.pump();

    TextField field(int i) =>
        tester.widget<TextField>(find.byType(TextField).at(i));
    expect(field(0).controller!.text, '2018');
    expect(field(1).controller!.text, '120000');
  });

  testWidgets('без города заказ не уходит', (tester) async {
    await openForm(tester);
    await pickCamry(tester);
    await submit(tester);

    expect(find.text('Выберите город поиска'), findsOneWidget);
    expect(find.byType(NewOrderScreen), findsOneWidget);
  });

  testWidgets('год вне границ — понятная ошибка до отправки', (tester) async {
    await openForm(tester);
    await pickCamry(tester);
    await tester.enterText(find.byType(TextField).at(0), '1985');
    await submit(tester);

    expect(find.textContaining('Год — от 1990'), findsOneWidget);
  });

  testWidgets('пробег за потолком — ошибка до отправки (QA №19)', (
    tester,
  ) async {
    await openForm(tester);
    await pickCamry(tester);
    await tester.enterText(find.byType(TextField).at(1), '3000000');
    await submit(tester);
    expect(find.text('Пробег — не больше 2 000 000 км'), findsOneWidget);

    // на границе пробег проходит — дальше форма спрашивает город
    ScaffoldMessenger.of(
      tester.element(find.byType(NewOrderScreen)),
    ).clearSnackBars();
    await tester.enterText(find.byType(TextField).at(1), '2000000');
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Пробег — не больше 2 000 000 км'), findsNothing);
    expect(find.text('Выберите город поиска'), findsOneWidget);
  });

  testWidgets('форма осмотра: пробег за потолком — ошибка до отправки', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: NewInspectionScreen(
          store: mockStore(
            orders: MockOrderRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Выбрать марку и модель'));
    await pickCamry(tester);

    Finder field(String label) => find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is FieldBoxInput && w.label == label,
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(field('Год'), '2019');
    await tester.enterText(field('Пробег'), '3000000');
    await tester.ensureVisible(find.text('Разместить осмотр'));
    await tester.tap(find.text('Разместить осмотр'));
    await tester.pump();

    expect(find.text('Пробег — не больше 2 000 000 км'), findsOneWidget);
    expect(find.byType(NewInspectionScreen), findsOneWidget);
  });
}
