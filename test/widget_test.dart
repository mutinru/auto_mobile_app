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
    expect(find.text('НЕ НАЧАТО'), findsOneWidget);

    // «Капот» оценён, значит лежит в «Готово» — до него надо доскроллить
    await tester.scrollUntilVisible(find.text('Капот'), 200);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Капот'));
    await tester.pumpAndSettle();

    expect(find.text('СОСТОЯНИЕ'), findsOneWidget);
  });
}
