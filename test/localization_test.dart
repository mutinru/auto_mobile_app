import 'package:auto_podbor_mobile/l10n/app_locale.dart';
import 'package:auto_podbor_mobile/theme/app_colors.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// №16 QA: встроенные виджеты Material (выбор времени и даты, меню
/// вставки) — по-русски и в цветах приложения, а не фиолетовые.
void main() {
  // приложение в той же настройке, что и main.dart
  Widget app(Widget home, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AppTheme.light,
    locale: appLocale,
    supportedLocales: appSupportedLocales,
    localizationsDelegates: appLocalizationsDelegates,
    home: Scaffold(body: home),
  );

  Widget opener(Future<void> Function(BuildContext) open) => Builder(
    builder: (context) => TextButton(
      onPressed: () => open(context),
      child: const Text('открыть'),
    ),
  );

  testWidgets('выбор времени — по-русски и 24 часа', (tester) async {
    await tester.pumpWidget(
      app(
        opener(
          (context) => showTimePicker(
            context: context,
            initialTime: const TimeOfDay(hour: 16, minute: 0),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();

    expect(find.text('Выберите время'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);
    expect(find.text('ОК'), findsOneWidget);
    // 24-часовой формат: 16 часов, а не 4 PM
    expect(find.text('16'), findsWidgets);
    expect(find.text('AM'), findsNothing);
    expect(find.text('PM'), findsNothing);
  });

  testWidgets('выбор даты — русские месяцы, неделя с понедельника', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        opener(
          (context) => showDatePicker(
            context: context,
            initialDate: DateTime(2026, 11, 10),
            firstDate: DateTime(2026, 11, 1),
            lastDate: DateTime(2027, 5, 1),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();

    expect(find.text('Выберите дату'), findsOneWidget);
    expect(find.textContaining('ноябрь 2026'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);
    final l = MaterialLocalizations.of(
      tester.element(find.text('Выберите дату')),
    );
    expect(l.firstDayOfWeekIndex, 1); // понедельник
  });

  testWidgets('меню в поле ввода — по-русски', (tester) async {
    final controller = TextEditingController(text: 'Москва');
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(TextField(controller: controller)));

    // по самому слову — тогда оно выделяется и всплывает меню
    final field = tester.getTopLeft(find.byType(EditableText));
    await tester.longPressAt(field + const Offset(12, 10));
    await tester.pumpAndSettle();

    expect(find.text('Копировать'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
  });

  test('системные тона схемы — из палитры, а не фиолетовые', () {
    for (final (theme, c) in [
      (AppTheme.light, AppColors.light),
      (AppTheme.dark, AppColors.dark),
    ]) {
      final s = theme.colorScheme;
      expect(s.primary, c.statusDone);
      expect(s.surfaceContainerHigh, c.bg1);
      expect(s.surfaceContainerHighest, c.bg2);
      for (final tone in [
        s.primaryContainer,
        s.secondary,
        s.secondaryContainer,
        s.tertiary,
        s.tertiaryContainer,
      ]) {
        // фиолетовый сид Material: синий канал заметно выше зелёного
        expect(tone.g, greaterThan(tone.b), reason: '$tone');
      }
      expect(theme.timePickerTheme.dialHandColor, c.statusDone);
      expect(theme.datePickerTheme.todayBorder?.color, c.statusDone);
    }
  });
}
