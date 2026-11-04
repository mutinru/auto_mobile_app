/// Когда исполнителю приезжать — зеркалит App\Enums\TimeSlot вместе с
/// часами (startHour/endHour на бекенде).
enum TimeSlot { morning, day, evening, exact }

extension TimeSlotX on TimeSlot {
  /// Подпись на чипе в форме осмотра (кадр 03).
  String get label => switch (this) {
    TimeSlot.morning => 'Утро',
    TimeSlot.day => 'День',
    TimeSlot.evening => 'Вечер',
    TimeSlot.exact => 'Точное время',
  };

  /// Начало окна по времени города; у точного времени окна нет.
  int? get startHour => switch (this) {
    TimeSlot.morning => 9,
    TimeSlot.day => 12,
    TimeSlot.evening => 17,
    TimeSlot.exact => null,
  };

  /// Конец окна: с этого часа слот на сегодня уже не выбрать.
  int? get endHour => switch (this) {
    TimeSlot.morning => 12,
    TimeSlot.day => 17,
    TimeSlot.evening => 21,
    TimeSlot.exact => null,
  };

  /// Чип с часами: «Утро · 9–12».
  String get chipLabel =>
      startHour == null ? label : '$label · $startHour–$endHour';

  /// Хвост строки «Сб, 19 сентября · днём» в карточке заказа.
  String get whenSuffix => switch (this) {
    TimeSlot.morning => 'утром',
    TimeSlot.day => 'днём',
    TimeSlot.evening => 'вечером',
    TimeSlot.exact => '',
  };

  String get apiValue => name;
}

TimeSlot? timeSlotFromApi(String? value) => switch (value) {
  'morning' => TimeSlot.morning,
  'day' => TimeSlot.day,
  'evening' => TimeSlot.evening,
  'exact' => TimeSlot.exact,
  _ => null,
};
