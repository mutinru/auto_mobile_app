/// Когда исполнителю приезжать — зеркалит App\Enums\TimeSlot.
enum TimeSlot { morning, day, evening, exact }

extension TimeSlotX on TimeSlot {
  /// Подпись на чипе в форме осмотра (кадр 03).
  String get label => switch (this) {
        TimeSlot.morning => 'Утро',
        TimeSlot.day => 'День',
        TimeSlot.evening => 'Вечер',
        TimeSlot.exact => 'Точное время',
      };

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
