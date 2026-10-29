/// Справочник марок и моделей с бекенда (GET /car-makes и
/// /car-makes/{id}/models). Только подсказки: в заказ уходят строки
/// brand/model, и значение не из справочника тоже допустимо.
///
/// [id] — код из источника (TOYOTA, VAZ), а не числовой id.
class CarMake {
  const CarMake({
    required this.id,
    required this.name,
    required this.nameRu,
    this.popular = false,
  });

  final String id;
  final String name;

  /// Кириллическое название — только для поиска, на экран не выводится.
  final String nameRu;
  final bool popular;

  factory CarMake.fromJson(Map<String, dynamic> json) => CarMake(
        id: json['id'] as String,
        name: json['name'] as String,
        nameRu: json['name_ru'] as String? ?? '',
        popular: json['popular'] as bool? ?? false,
      );

  bool matches(String query) => catalogMatches(query, name, nameRu);
}

class CarModel {
  const CarModel({
    required this.id,
    required this.name,
    required this.nameRu,
    this.yearFrom,
    this.yearTo,
  });

  final String id;
  final String name;
  final String nameRu;
  final int? yearFrom;
  final int? yearTo;

  factory CarModel.fromJson(Map<String, dynamic> json) => CarModel(
        id: json['id'] as String,
        name: json['name'] as String,
        nameRu: json['name_ru'] as String? ?? '',
        yearFrom: json['year_from'] as int?,
        yearTo: json['year_to'] as int?,
      );

  /// «2015–2026», «2024» или null, если годы неизвестны.
  String? get years {
    if (yearFrom == null) return null;
    if (yearTo == null || yearTo == yearFrom) return '$yearFrom';
    return '$yearFrom–$yearTo';
  }

  bool matches(String query) => catalogMatches(query, name, nameRu);
}

/// Поиск по латинице и кириллице без учёта регистра и разницы «ё/е»:
/// «тойота» находит Toyota, «ВАЗ» — Lada (ВАЗ).
bool catalogMatches(String query, String name, String nameRu) {
  final q = normalizeSearch(query.trim());
  if (q.isEmpty) return true;
  return normalizeSearch(name).contains(q) || normalizeSearch(nameRu).contains(q);
}

/// Нижний регистр и «ё» → «е» — общая нормализация поиска по справочникам.
String normalizeSearch(String s) => s.toLowerCase().replaceAll('ё', 'е');
