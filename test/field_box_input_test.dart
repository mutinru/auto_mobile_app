import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/theme/app_colors.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/app_ui.dart';

/// Рекомендация и ошибка под полем: рамка и строка под ним.
void main() {
  late TextEditingController text;
  setUp(() => text = TextEditingController());
  tearDown(() => text.dispose());

  Future<BuildContext> pump(
    WidgetTester tester, {
    String? error,
    String? warning,
    String? helper,
  }) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return FieldBoxInput(
                label: '',
                controller: text,
                error: error,
                warning: warning,
                helper: helper,
              );
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  /// Цвет рамки поля ввода.
  Color border(WidgetTester tester) {
    final box = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null);
    return (box.border! as Border).top.color;
  }

  testWidgets('рекомендация — оранжевая рамка и строка с иконкой под полем', (
    tester,
  ) async {
    final ctx = await pump(tester, warning: 'Проверьте каждый знак');

    expect(find.byType(FieldWarning), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(border(tester), ctx.colors.statusProgress);
    // строка — под полем, а не над ним
    expect(
      tester.getTopLeft(find.text('Проверьте каждый знак')).dy,
      greaterThan(tester.getBottomLeft(find.byType(TextField)).dy),
    );
  });

  testWidgets('ошибка показывается вместо рекомендации, рамка красная', (
    tester,
  ) async {
    final ctx = await pump(
      tester,
      error: 'В VIN 17 символов',
      warning: 'Проверьте каждый знак',
      helper: 'Сверьте с фото',
    );

    expect(find.text('В VIN 17 символов'), findsOneWidget);
    expect(find.text('Проверьте каждый знак'), findsNothing);
    expect(find.text('Сверьте с фото'), findsNothing);
    expect(border(tester), ctx.colors.statusDefect);
  });

  testWidgets('пояснение — серая строка, рамка обычная', (tester) async {
    final ctx = await pump(tester, helper: 'Сверьте с фото');

    expect(find.text('Сверьте с фото'), findsOneWidget);
    expect(find.byType(FieldWarning), findsNothing);
    expect(border(tester), ctx.colors.line);
  });
}
