import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/models/inspection_verdict.dart';
import 'package:auto_podbor_mobile/screens/faq_screen.dart';
import 'package:auto_podbor_mobile/screens/intent_screen.dart';
import 'package:auto_podbor_mobile/theme/app_colors.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/theme/theme_controller.dart';
import 'package:auto_podbor_mobile/widgets/app_ui.dart';
import 'package:auto_podbor_mobile/widgets/inspection_order_parts.dart';
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
    // телефона у поддержки нет (QA №25)
    expect(find.text('Позвонить'), findsNothing);
    expect(find.text('Частые вопросы'), findsOneWidget);

    await tester.tap(find.text('Частые вопросы'));
    await tester.pumpAndSettle();

    expect(find.byType(FaqScreen), findsOneWidget);
    expect(find.text('Как работает подбор?'), findsOneWidget);
  });

  group('светлая тема: буквы акцентов — тёмные *Text, не яркие status*', () {
    Widget light(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

    testWidgets('TextButton без своего цвета — doneText', (tester) async {
      await tester.pumpWidget(
        light(TextButton(onPressed: () {}, child: const Text('Повторить'))),
      );

      final style = DefaultTextStyle.of(
        tester.element(find.text('Повторить')),
      ).style;
      expect(style.color, AppColors.light.doneText);
    });

    testWidgets('вердикт осмотра — подпись и иконка цветом букв', (
      tester,
    ) async {
      await tester.pumpWidget(
        light(
          const InspectionVerdictBox(verdict: InspectionVerdict.recommended),
        ),
      );

      final label = tester.widget<Text>(find.text('Можно брать'));
      expect(label.style?.color, AppColors.light.doneText);
      final icon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(icon.color, AppColors.light.doneText);
    });
  });

  testWidgets('невыбранный чип: в светлой теме с рамкой, в тёмной без', (
    tester,
  ) async {
    Future<Color> edge(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: AppChip(label: 'Автомат', on: false)),
        ),
      );
      // смена темы у MaterialApp анимируется — ждём последний кадр
      await tester.pumpAndSettle();
      final box =
          tester
                  .widget<Container>(
                    find.ancestor(
                      of: find.text('Автомат'),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      return (box.border! as Border).top.color;
    }

    // белый чип на светло-сером фоне без рамки на солнце не виден
    expect(await edge(AppTheme.light), AppColors.light.line);
    expect(await edge(AppTheme.dark), AppColors.dark.chipEdge);
    expect(AppColors.dark.chipEdge.a, 0);
  });

  testWidgets('подпись поля: в светлой теме темнее и жирнее, тёмная как была', (
    tester,
  ) async {
    Future<TextStyle> label(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: FieldLabel('Марка и модель')),
        ),
      );
      await tester.pumpAndSettle();
      return tester.widget<Text>(find.text('МАРКА И МОДЕЛЬ')).style!;
    }

    // 10 px заглавными: text3 на солнце бледнеет
    final light = await label(AppTheme.light);
    expect(light.color, AppColors.light.text1);
    expect(light.fontWeight, FontWeight.w700);

    final dark = await label(AppTheme.dark);
    expect(dark.color, AppColors.dark.text3);
    expect(dark.fontWeight, FontWeight.w600);
  });

  testWidgets('«необязательно» на ступень светлее чёрной подписи', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: FieldLabel('Госномер', optional: true)),
      ),
    );
    await tester.pumpAndSettle();

    final note = tester.widget<Text>(find.text('необязательно')).style!;
    expect(note.color, AppColors.light.text2);
  });

  testWidgets('пояснение под полем: в светлой теме чёрное, тёмная как была', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    Future<Color?> helper(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: FieldBoxInput(
              label: 'VIN',
              controller: controller,
              helper: 'Снимок таблички есть',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .widget<Text>(find.text('Снимок таблички есть'))
          .style!
          .color;
    }

    expect(await helper(AppTheme.light), AppColors.light.text1);
    expect(await helper(AppTheme.dark), AppColors.dark.text2);
  });
}
