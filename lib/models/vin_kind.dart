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
/// прилипнет к номеру. Склеиваем не всякую строку ([_glueable]).
///
/// Берётся первое совпадение по порядку текста: снимок с рамкой отдаёт
/// строки от ближайшей к центру рамки (`textNearest`), так что побеждает
/// строка, на которую наводили, а не верхняя на табличке.
String? extractVin(String text) {
  final upper = text.toUpperCase();
  final whole = RegExp(r'(?<![A-Z0-9])[A-HJ-NPR-Z0-9]{17}(?![A-Z0-9])');
  final exact = whole.firstMatch(upper)?.group(0);
  if (exact != null) return exact;
  for (final line in upper.split('\n')) {
    if (!_glueable(line)) continue;
    final cleaned = line
        .replaceAll(RegExp(r'\bVIN\b'), '')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final match = RegExp(r'[A-HJ-NPR-Z0-9]{17}').firstMatch(cleaned);
    if (match != null) return match.group(0);
  }
  return null;
}

/// Лучшая догадка о VIN, когда [extractVin] целого не нашёл: строка,
/// похожая на VIN, даже если знаков меньше 17 или OCR прочитал 0 как O.
/// Нужна шторке сверки — исполнитель допишет недостающее по фото, а не
/// наберёт всё заново. I, O и Q в VIN не бывает, поэтому меняем их на
/// 1 и 0, но не больше двух замен: больше — скорее мусор (текст, прочитанный
/// вверх ногами), чем VIN. Чтобы не принять за VIN надпись вроде TOYOTA
/// MOTOR CORPORATION, в строке должно быть хотя бы четыре цифры — у VIN их
/// обычно шесть и больше. Короче 10 знаков — не догадка.
String? guessVin(String text) {
  final full = extractVin(text);
  if (full != null) return full;
  String? best;
  for (final line in text.toUpperCase().split('\n')) {
    if (!_glueable(line)) continue;
    final cleaned = line
        .replaceAll(RegExp(r'\bVIN\b'), '')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (RegExp(r'[0-9]').allMatches(cleaned).length < 4) continue;
    final head = cleaned.length > 17 ? cleaned.substring(0, 17) : cleaned;
    if (RegExp(r'[IOQ]').allMatches(head).length > 2) continue;
    final normalized = cleaned
        .replaceAll('I', '1')
        .replaceAll('O', '0')
        .replaceAll('Q', '0');
    if (normalized.length < 10) continue;
    final candidate = normalized.length > 17
        ? normalized.substring(0, 17)
        : normalized;
    if (best == null || candidate.length > best.length) best = candidate;
  }
  return best;
}

/// Можно ли склеить строку в VIN. OCR разбивает VIN на 2–3 куска
/// («XW8 ZZZ61Z KG100111»), а соседние строки шильдика — это много слов и
/// дефисы: «MAX 1650 KG 1-860 KG 2-1000 KG» без разделителей тоже даёт 17
/// «VIN-знаков» (QA 2026-11-05 №4). Поэтому: не больше четырёх кусков
/// (подпись «VIN» не в счёт) и никаких дефисов между буквами и цифрами.
bool _glueable(String line) {
  final upper = line.toUpperCase();
  if (RegExp(r'[A-Z0-9]\s*-\s*[A-Z0-9]').hasMatch(upper)) return false;
  final pieces = upper
      .replaceAll(RegExp(r'\bVIN\b'), ' ')
      .split(RegExp(r'[^A-Z0-9]+'))
      .where((p) => p.isNotEmpty);
  return pieces.length <= 4;
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
