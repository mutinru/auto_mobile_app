/// Что исполнитель снял с таблички — зеркало App\Enums\VinKind на бекенде.
/// Номер кузова — у японских праворульных и части старых машин, VIN у них нет.
enum VinKind { vin, bodyNumber }

extension VinKindX on VinKind {
  String get label => switch (this) {
    VinKind.vin => 'VIN',
    VinKind.bodyNumber => 'Номер кузова',
  };

  String get apiValue => switch (this) {
    VinKind.vin => 'vin',
    VinKind.bodyNumber => 'body_number',
  };

  /// null, если значение подходит, иначе — текст ошибки. Правила —
  /// как у сервера (`App\Support\VinRules`).
  String? problem(String value) => switch (this) {
    VinKind.vin when !vinPattern.hasMatch(value) =>
      'VIN — 17 символов, без I, O и Q',
    VinKind.bodyNumber when !bodyNumberPattern.hasMatch(value) =>
      'Номер кузова — например GX110-6012345',
    _ => null,
  };
}

VinKind? vinKindFromApi(String? value) => switch (value) {
  'vin' => VinKind.vin,
  'body_number' => VinKind.bodyNumber,
  _ => null,
};

final vinPattern = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');
final bodyNumberPattern = RegExp(r'^[A-Z0-9]{2,10}-?[0-9]{4,8}$');

/// VIN, снятый исполнителем: значение, вид и фото таблички (путь к файлу
/// на устройстве). Без фото сервер осмотр не начнёт.
class CapturedVin {
  const CapturedVin({
    required this.value,
    required this.kind,
    required this.photoPath,
  });

  final String value;
  final VinKind kind;
  final String photoPath;
}

/// Пробег по одометру, снятый исполнителем, и фото приборки (путь к файлу
/// на устройстве). Цифры вводит исполнитель, снимок — доказательство.
class CapturedOdometer {
  const CapturedOdometer({required this.km, required this.photoPath});

  final int km;
  final String photoPath;
}

/// Ищем в распознанном тексте 17 допустимых для VIN знаков. I, O и Q в VIN
/// не встречаются — это отсеивает ложные срабатывания на обычных словах.
/// Сначала — отдельное слово ровно из 17 знаков; не нашлось (OCR разбил
/// VIN пробелами) — склеиваем строку, убрав подпись «VIN», иначе её N
/// прилипнет к номеру.
String? extractVin(String text) {
  final upper = text.toUpperCase();
  final whole = RegExp(r'(?<![A-Z0-9])[A-HJ-NPR-Z0-9]{17}(?![A-Z0-9])');
  final exact = whole.firstMatch(upper)?.group(0);
  if (exact != null) return exact;
  for (final line in upper.split('\n')) {
    final cleaned = line
        .replaceAll(RegExp(r'\bVIN\b'), '')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final match = RegExp(r'[A-HJ-NPR-Z0-9]{17}').firstMatch(cleaned);
    if (match != null) return match.group(0);
  }
  return null;
}

/// Номер кузова на табличке: модель шасси, дефис, серийный номер
/// (`GX110-6012345`, `JZX100 0123456`). Разделитель приводим к дефису.
String? extractBodyNumber(String text) {
  final match = RegExp(
    r'\b([A-Z]{1,4}[0-9]{1,3}[A-Z]?)\s*[-–—]?\s*([0-9]{5,7})\b',
  ).firstMatch(text.toUpperCase());
  if (match == null) return null;
  return '${match.group(1)}-${match.group(2)}';
}
