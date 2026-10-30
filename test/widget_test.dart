import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/screens/inspection_overview_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

void main() {
  testWidgets('Overview opens on the schematic tab and lists panels on the list tab',
      (tester) async {
    final store = InspectionStore(MockInspectionRepository());

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: InspectionOverviewScreen(store: store),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Toyota Camry 2019'), findsOneWidget);
    // по умолчанию — «Схема»: детали нарисованы на канве, текста нет
    expect(find.text('Капот'), findsNothing);

    await tester.tap(find.text('Список'));
    await tester.pumpAndSettle();

    // список сгруппирован по состоянию работы
    expect(find.text('ТРЕБУЕТ ВНИМАНИЯ'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('НЕ НАЧАТО'), 200);
    expect(find.text('НЕ НАЧАТО'), findsOneWidget);

    // «Капот» оценён, значит лежит в «Готово» — до него надо доскроллить
    await tester.scrollUntilVisible(find.text('Капот'), 200);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Капот'));
    await tester.pumpAndSettle();

    expect(find.text('СОСТОЯНИЕ'), findsOneWidget);
  });

  testWidgets('Боковые кнопки схемы открывают пункт со своими дефектами',
      (tester) async {
    final store = InspectionStore(MockInspectionRepository());

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: InspectionOverviewScreen(store: store),
    ));
    await tester.pumpAndSettle();

    for (final name in ['Двигатель', 'Пороги', 'Окна', 'Документы']) {
      expect(find.text(name), findsOneWidget);
    }

    await tester.tap(find.text('Двигатель'));
    await tester.pumpAndSettle();

    expect(find.text('Течь масла'), findsOneWidget);
    expect(find.text('Царапины'), findsNothing);
  });

  group('Схема подсказывает, с чего начать', () {
    const executorHint = 'Нажмите на деталь или пункт сбоку';

    Future<InspectionStore> open(
      WidgetTester tester,
      MockInspectionRepository repository, {
      bool readOnly = false,
    }) async {
      final store = InspectionStore(repository, readOnly: readOnly);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: InspectionOverviewScreen(store: store),
      ));
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('новый осмотр: подсказка и «Начать осмотр» с первого пункта',
        (tester) async {
      await open(tester, MockInspectionRepository.blank());

      expect(find.text(executorHint), findsOneWidget);
      expect(find.text('НАЧАТЬ ОСМОТР'), findsOneWidget);
      expect(find.text('Передний бампер'), findsOneWidget);

      await tester.tap(find.text('НАЧАТЬ ОСМОТР'));
      await tester.pumpAndSettle();
      expect(find.text('СОСТОЯНИЕ'), findsOneWidget);

      await tester.tap(find.text('Хорошее'));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      // после первой оценки подсказка уходит, кнопка ведёт дальше
      expect(find.text(executorHint), findsNothing);
      expect(find.text('ПРОДОЛЖИТЬ'), findsOneWidget);
      expect(find.text('Переднее левое крыло'), findsOneWidget);
    });

    testWidgets('начатый осмотр: без подсказки, «Продолжить» с первого неоценённого',
        (tester) async {
      await open(tester, MockInspectionRepository());

      expect(find.text(executorHint), findsNothing);
      expect(find.text('ПРОДОЛЖИТЬ'), findsOneWidget);
      expect(find.text('Заднее левое крыло'), findsOneWidget);
    });

    testWidgets('заказчик: своя подсказка, без кнопки осмотра', (tester) async {
      await open(tester, MockInspectionRepository.blank(), readOnly: true);

      expect(find.text('Нажмите на деталь, чтобы посмотреть оценку'), findsOneWidget);
      expect(find.text(executorHint), findsNothing);
      expect(find.text('НАЧАТЬ ОСМОТР'), findsNothing);
    });
  });
}
