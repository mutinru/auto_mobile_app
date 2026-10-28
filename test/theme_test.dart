import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/screens/faq_screen.dart';
import 'package:auto_podbor_mobile/screens/intent_screen.dart';
import 'package:auto_podbor_mobile/theme/app_colors.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/theme/theme_controller.dart';
import 'package:auto_podbor_mobile/widgets/theme_switch.dart';

void main() {
  /// Та же связка, что в main.dart: ThemeScope + MaterialApp на контроллере.
  /// Хранилища в тестах нет — контроллер это глотает и живёт в памяти.
  Widget app(ThemeController theme) => ThemeScope(
    controller: theme,
    child: ListenableBuilder(
      listenable: theme,
      builder: (_, _) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: theme.mode,
        home: IntentScreen(onChoose: (_) {}),
      ),
    ),
  );

  Color scaffoldBg(WidgetTester tester) => Theme.of(
    tester.element(find.byType(IntentScreen)),
  ).scaffoldBackgroundColor;

  testWidgets('по умолчанию тёмная, переключатель включает светлую', (
    tester,
  ) async {
    final theme = ThemeController();
    await tester.pumpWidget(app(theme));

    expect(scaffoldBg(tester), AppColors.dark.bg0);

    await tester.tap(find.byType(ThemeSwitch));
    await tester.pumpAndSettle();

    expect(theme.isLight, isTrue);
    expect(scaffoldBg(tester), AppColors.light.bg0);
    // экран читает палитру из темы, а не из констант
    final title = tester.widget<Text>(find.text('Что вас сюда привело?'));
    expect(title.style?.color, AppColors.light.text1);

    await tester.tap(find.byType(ThemeSwitch));
    await tester.pumpAndSettle();
    expect(scaffoldBg(tester), AppColors.dark.bg0);
  });

  testWidgets('«Поддержка» открывает шторку, оттуда — частые вопросы', (
    tester,
  ) async {
    await tester.pumpWidget(app(ThemeController()));

    await tester.tap(find.text('Поддержка'));
    await tester.pumpAndSettle();

    expect(find.text('Написать в чат'), findsOneWidget);
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Позвонить'), findsOneWidget);
    expect(find.text('Частые вопросы'), findsOneWidget);

    await tester.tap(find.text('Частые вопросы'));
    await tester.pumpAndSettle();

    expect(find.byType(FaqScreen), findsOneWidget);
    expect(find.text('Как работает подбор?'), findsOneWidget);
  });
}
