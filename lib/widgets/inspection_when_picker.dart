import 'package:flutter/material.dart';

import '../models/time_slot.dart';
import '../theme/app_colors.dart';
import '../util/ru_date.dart';
import 'app_ui.dart';

/// Когда осматривать: день, слот и точное время (если слот — точное).
class InspectionWhen {
  const InspectionWhen({
    required this.date,
    required this.slot,
    this.exactTime,
  });

  final DateTime date;
  final TimeSlot slot;
  final TimeOfDay? exactTime;

  /// «16:00» для слота «точное время», иначе null.
  String? get inspectTime {
    final t = exactTime;
    if (slot != TimeSlot.exact || t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  InspectionWhen copyWith({
    DateTime? date,
    TimeSlot? slot,
    TimeOfDay? exactTime,
  }) => InspectionWhen(
    date: date ?? this.date,
    slot: slot ?? this.slot,
    exactTime: exactTime ?? this.exactTime,
  );
}

/// «16:00» с сервера → TimeOfDay; null — времени нет или оно кривое.
TimeOfDay? parseInspectTime(String? value) {
  final parts = value?.split(':');
  if (parts == null || parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  return hour == null || minute == null
      ? null
      : TimeOfDay(hour: hour, minute: minute);
}

/// С этого часа «сегодня» для осмотра закрыто — как App\Support\InspectionDay
/// на сервере. Тут — по часам устройства; сервер всё равно проверит по
/// времени города осмотра и ответит 422.
const todayCutoffHour = 21;

/// Первый день, на который ещё можно назначить осмотр: сегодня, а после
/// [todayCutoffHour] — завтра.
DateTime firstInspectionDay(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return now.hour >= todayCutoffHour
      ? today.add(const Duration(days: 1))
      : today;
}

/// Чипы дня (три ближайших доступных + календарь) и слота времени — форма
/// нового осмотра и лист «Разместить заново». [now] — для тестов.
class InspectionWhenPicker extends StatelessWidget {
  const InspectionWhenPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.now,
  });

  final InspectionWhen value;
  final ValueChanged<InspectionWhen> onChanged;
  final DateTime Function()? now;

  DateTime get _now => (now ?? DateTime.now)();

  List<DateTime> get _dateOptions {
    final first = firstInspectionDay(_now);
    return [for (var i = 0; i < 3; i++) first.add(Duration(days: i))];
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate(BuildContext context) async {
    final first = firstInspectionDay(_now);
    final picked = await showDatePicker(
      context: context,
      initialDate: value.date.isBefore(first) ? first : value.date,
      firstDate: first,
      lastDate: _now.add(const Duration(days: 180)),
    );
    if (picked != null) onChanged(value.copyWith(date: picked));
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: value.exactTime ?? const TimeOfDay(hour: 16, minute: 0),
    );
    if (picked != null) {
      onChanged(value.copyWith(exactTime: picked, slot: TimeSlot.exact));
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _dateOptions;
    final other = !options.any((d) => _sameDay(value.date, d));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final option in options)
              AppChip(
                label: shortDate(option),
                on: _sameDay(value.date, option),
                activeColor: context.colors.statusDone,
                onTap: () => onChanged(value.copyWith(date: option)),
              ),
            AppChip(
              label: other ? shortDate(value.date) : 'Другая дата',
              on: other,
              activeColor: context.colors.statusDone,
              onTap: () => _pickDate(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final slot in TimeSlot.values)
              AppChip(
                label: slot == TimeSlot.exact
                    ? (value.inspectTime ?? slot.label)
                    : slot.label,
                on: value.slot == slot,
                activeColor: context.colors.statusDone,
                onTap: () => slot == TimeSlot.exact
                    ? _pickTime(context)
                    : onChanged(value.copyWith(slot: slot)),
              ),
          ],
        ),
      ],
    );
  }
}
