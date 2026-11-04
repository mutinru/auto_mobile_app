import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/models/time_slot.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/app_ui.dart';
import 'package:auto_podbor_mobile/widgets/inspection_when_picker.dart';

/// На сегодня закончившийся слот и точное время ближе двух часов не
/// выбрать (QA №17): утро 9–12, день 12–17, вечер 17–21.
void main() {
  // подписи дней («Сегодня») считаются от настоящих часов — день берём
  // реальный, время фиксируем
  final real = DateTime.now();
  final now = DateTime(real.year, real.month, real.day, 15, 16);
  final today = DateTime(real.year, real.month, real.day);
  final tomorrow = today.add(const Duration(days: 1));

  test('часы слотов — зеркало бекенда', () {
    expect(TimeSlot.morning.chipLabel, 'Утро · 9–12');
    expect(TimeSlot.day.chipLabel, 'День · 12–17');
    expect(TimeSlot.evening.chipLabel, 'Вечер · 17–21');
    expect(TimeSlot.exact.chipLabel, 'Точное время');
  });

  test('слот на сегодня открыт, пока не кончился', () {
    expect(slotOpen(now, today, TimeSlot.morning), isFalse);
    expect(slotOpen(now, today, TimeSlot.day), isTrue);
    expect(slotOpen(now, today, TimeSlot.evening), isTrue);
    expect(slotOpen(now, tomorrow, TimeSlot.morning), isTrue);
    expect(
      slotOpen(today.add(const Duration(hours: 17)), today, TimeSlot.day),
      isFalse,
    );
  });

  test('точное время на сегодня — не раньше чем через 2 часа', () {
    expect(
      earliestExactTime(now, today),
      const TimeOfDay(hour: 17, minute: 20),
    );
    expect(earliestExactTime(now, tomorrow), isNull);
  });

  test('подгонка: прошедший слот → первый открытый, близкое время — сброс', () {
    final fitted = fitWhen(
      InspectionWhen(date: today, slot: TimeSlot.morning),
      now,
    );
    expect(fitted.slot, TimeSlot.day);

    final exact = fitWhen(
      InspectionWhen(
        date: today,
        slot: TimeSlot.exact,
        exactTime: const TimeOfDay(hour: 16, minute: 0),
      ),
      now,
    );
    expect(exact.exactTime, isNull);

    final ok = InspectionWhen(date: tomorrow, slot: TimeSlot.morning);
    expect(fitWhen(ok, now), same(ok));
  });

  testWidgets('на сегодня «Утро» неактивно, выбор сегодня переключает слот', (
    tester,
  ) async {
    var value = InspectionWhen(date: tomorrow, slot: TimeSlot.morning);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => InspectionWhenPicker(
              value: value,
              now: () => now,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );

    AppChip chip(String label) => tester.widget<AppChip>(
      find.ancestor(of: find.text(label), matching: find.byType(AppChip)),
    );

    // завтра — всё доступно
    expect(chip('Утро · 9–12').enabled, isTrue);

    await tester.tap(find.text('Сегодня').first);
    await tester.pumpAndSettle();

    expect(value.date, today);
    expect(value.slot, TimeSlot.day);
    expect(chip('Утро · 9–12').enabled, isFalse);
    expect(chip('День · 12–17').enabled, isTrue);
    expect(
      find.text('Точное время на сегодня — не раньше 17:20'),
      findsOneWidget,
    );
  });
}
