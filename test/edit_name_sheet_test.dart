import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/edit_name_sheet.dart';

void main() {
  /// Открывает лист с кнопки, чтобы проверить и закрытие после сохранения.
  Future<void> openSheet(
    WidgetTester tester,
    Future<void> Function(String) onSave,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEditNameSheet(
                context,
                initial: 'Пользователь 0003',
                onSave: onSave,
              ),
              child: const Text('открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();
  }

  ElevatedButton saveButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets('кнопка неактивна, пока имя не изменилось или пустое', (
    tester,
  ) async {
    await openSheet(tester, (_) async {});

    expect(find.text('Пользователь 0003'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Иван');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('сохраняет обрезанное имя и закрывает лист', (tester) async {
    String? saved;
    await openSheet(tester, (name) async => saved = name);

    await tester.enterText(find.byType(TextField), '  Иван Петров  ');
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(saved, 'Иван Петров');
    expect(find.text('Как вас зовут'), findsNothing);
  });

  testWidgets('ошибка сервера показывается, лист остаётся открытым', (
    tester,
  ) async {
    await openSheet(
      tester,
      (_) async => throw ApiException(422, 'Имя слишком длинное'),
    );

    await tester.enterText(find.byType(TextField), 'Иван');
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Имя слишком длинное'), findsOneWidget);
    expect(find.text('Как вас зовут'), findsOneWidget);
  });
}
