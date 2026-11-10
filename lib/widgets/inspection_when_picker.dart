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

/// На сколько дней вперёд можно назначить осмотр — зеркало
/// InspectionDay::MAX_DAYS_AHEAD на сервере (дальше — 422).
const maxInspectionDaysAhead = 10;

/// Первый день, на который ещё можно назначить осмотр: сегодня, а после
/// [todayCutoffHour] — завтра.
DateTime firstInspectionDay(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return now.hour >= todayCutoffHour
      ? today.add(const Duration(days: 1))
      : today;
}

/// Точное время на сегодня — не раньше чем через столько часов
/// (InspectionDay::EXACT_LEAD_HOURS на бекенде).
const exactLeadHours = 2;

bool _isToday(DateTime date, DateTime now) =>
    date.year == now.year && date.month == now.month && date.day == now.day;

/// Можно ли ещё выбрать слот на [date]: на сегодня — пока он не кончился
/// (InspectionDay::slotProblem). Точное время проверяет [earliestExactTime].
bool slotOpen(DateTime now, DateTime date, TimeSlot slot) {
  final end = slot.endHour;
  return end == null || !_isToday(date, now) || now.hour < end;
}

/// Самое раннее точное время на [date]: на сегодня — сейчас + 2 ч, вверх
/// до 5 минут (15:16 → 17:20); на другой день — без ограничения (null).
TimeOfDay? earliestExactTime(DateTime now, DateTime date) {
  if (!_isToday(date, now)) return null;
  var at = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  ).add(const Duration(hours: exactLeadHours));
  at = at.add(Duration(minutes: (5 - at.minute % 5) % 5));
  // перевалило за полночь — на сегодня точного времени уже нет
  if (!_isToday(at, now)) return const TimeOfDay(hour: 23, minute: 59);
  return TimeOfDay(hour: at.hour, minute: at.minute);
}

bool _before(TimeOfDay a, TimeOfDay b) =>
    a.hour < b.hour || (a.hour == b.hour && a.minute < b.minute);

/// Выбор, подогнанный к текущему моменту: слот на сегодня кончился — первый
/// ещё открытый; точное время на сегодня слишком близко — сбрасываем его,
/// чтобы заказчик выбрал заново. Сервер всё равно проверит по городу.
InspectionWhen fitWhen(InspectionWhen when, DateTime now) {
  if (when.slot == TimeSlot.exact) {
    final earliest = earliestExactTime(now, when.date);
    final time = when.exactTime;
    if (earliest != null && time != null && _before(time, earliest)) {
      return InspectionWhen(date: when.date, slot: when.slot);
    }
    return when;
  }
  if (slotOpen(now, when.date, when.slot)) return when;
  final open = TimeSlot.values.firstWhere(
    (s) => s != TimeSlot.exact && slotOpen(now, when.date, s),
    orElse: () => TimeSlot.exact,
  );
  return when.copyWith(slot: open);
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

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate(BuildContext context) async {
    final first = firstInspectionDay(_now);
    final picked = await showDatePicker(
      context: context,
      initialDate: value.date.isBefore(first) ? first : value.date,
      firstDate: first,
      lastDate: DateTime(
        _now.year,
        _now.month,
        _now.day,
      ).add(const Duration(days: maxInspectionDaysAhead)),
    );
    if (picked != null) _changeDate(picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final earliest = earliestExactTime(_now, value.date);
    var initial = value.exactTime ?? const TimeOfDay(hour: 16, minute: 0);
    if (earliest != null && _before(initial, earliest)) initial = earliest;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    // раньше границы не принимаем — подсказка под чипами говорит, с какого
    if (earliest != null && _before(picked, earliest)) return;
    onChanged(value.copyWith(exactTime: picked, slot: TimeSlot.exact));
  }

  /// Смена дня: на сегодня прошедший слот переключается на открытый.
  void _changeDate(DateTime date) =>
      onChanged(fitWhen(value.copyWith(date: date), _now));

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
                onTap: () => _changeDate(option),
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
                    : slot.chipLabel,
                on: value.slot == slot,
                // на сегодня закончившийся слот не выбрать
                enabled: slotOpen(_now, value.date, slot),
                activeColor: context.colors.statusDone,
                onTap: () => slot == TimeSlot.exact
                    ? _pickTime(context)
                    : onChanged(value.copyWith(slot: slot)),
              ),
          ],
        ),
        if (earliestExactTime(_now, value.date) case final earliest?) ...[
          const SizedBox(height: 6),
          Text(
            'Точное время на сегодня — не раньше ${_hhmm(earliest)}',
            style: TextStyle(fontSize: 11.5, color: context.colors.text3),
          ),
        ],
      ],
    );
  }
}
