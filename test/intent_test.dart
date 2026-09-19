import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/screens/intent_screen.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

void main() {
  /// Отдаёт экран и список того, что он успел выбрать.
  (Widget, List<AppIntent>) build() {
    final chosen = <AppIntent>[];
    return (
      MaterialApp(
        theme: AppTheme.dark,
        home: IntentScreen(onChoose: chosen.add),
      ),
      chosen,
    );
  }

  testWidgets('стартовый экран показывает вопрос и три варианта', (tester) async {
    final (app, _) = build();
    await tester.pumpWidget(app);

    expect(find.text('Что вас сюда привело?'), findsOneWidget);
    expect(find.text('Ищу автомобиль'), findsOneWidget);
    expect(find.text('Беру заказы на подбор'), findsOneWidget);
    expect(find.text('Просто посмотрю'), findsOneWidget);
  });

  testWidgets('«Просто посмотрю» отдаёт browse', (tester) async {
    final (app, chosen) = build();
    await tester.pumpWidget(app);

    await tester.tap(find.text('Просто посмотрю'));
    await tester.pump();

    expect(chosen, [AppIntent.browse]);
  });

  testWidgets('карточки отдают свои намерения', (tester) async {
    final (app, chosen) = build();
    await tester.pumpWidget(app);

    await tester.tap(find.text('Ищу автомобиль'));
    await tester.pump();
    await tester.tap(find.text('Беру заказы на подбор'));
    await tester.pump();

    expect(chosen, [AppIntent.buy, AppIntent.work]);
  });
}
