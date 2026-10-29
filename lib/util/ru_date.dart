import '../models/time_slot.dart';

/// Русские даты без пакета intl (его нет в pubspec) — в том же духе,
/// что money() и initialsOf() в widgets/app_ui.dart.
const _months = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];

const _monthsShort = [
  'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
];

const _weekdaysShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// «19 сентября»
String dayMonth(DateTime date) => '${date.day} ${_months[date.month - 1]}';

/// Короткая дата для чипа: «Сегодня», «Завтра», «Сб, 19 сен».
String shortDate(DateTime date) => switch (_daysFromToday(date)) {
      0 => 'Сегодня',
      1 => 'Завтра',
      _ => '${_weekdaysShort[date.weekday - 1]}, ${date.day} ${_monthsShort[date.month - 1]}',
    };

/// Строка «когда» для карточки и детали осмотра:
/// «Завтра, 16:00», «Сб, 19 сентября · днём», «14 сентября».
String whenLabel(DateTime? date, TimeSlot? slot, String? exactTime) {
  if (date == null) return 'дата не указана';

  final time = slot == TimeSlot.exact ? exactTime : null;
  final suffix = time ?? slot?.whenSuffix ?? '';
  final days = _daysFromToday(date);

  final head = switch (days) {
    0 => 'Сегодня',
    1 => 'Завтра',
    _ when days > 1 && days < 7 => '${_weekdaysShort[date.weekday - 1]}, ${dayMonth(date)}',
    _ => dayMonth(date),
  };

  if (suffix.isEmpty) return head;
  // «Завтра, 16:00», но «Сб, 19 сентября · днём»
  return time != null ? '$head, $time' : '$head · $suffix';
}

/// Прошедший осмотр в списке завершённых: «14 сентября».
String pastDate(DateTime? date) => date == null ? '—' : dayMonth(date);

/// Разделитель дней в чате: «Сегодня», «Вчера», «14 сентября»,
/// для прошлых лет — «14 сентября 2025».
String chatDay(DateTime date) => switch (_daysFromToday(date)) {
      0 => 'Сегодня',
      -1 => 'Вчера',
      _ when date.year == DateTime.now().year => dayMonth(date),
      _ => '${dayMonth(date)} ${date.year}',
    };

/// «09:05»
String hhmm(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

int _daysFromToday(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(date.year, date.month, date.day).difference(today).inDays;
}
