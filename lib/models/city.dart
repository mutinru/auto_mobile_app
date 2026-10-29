/// Город из справочника бекенда (GET /cities, /cities/nearest). Только
/// подсказка: в заказ уходит строка [name], и город не из справочника
/// тоже допустим.
///
/// [id] — fias_id, а не числовой id.
class City {
  const City({
    required this.id,
    required this.name,
    required this.region,
    required this.lat,
    required this.lon,
    this.population,
    this.distanceKm,
  });

  final String id;
  final String name;

  /// «Московская обл», «Респ Татарстан»; у Москвы и СПб совпадает с [name].
  final String region;
  final double lat;
  final double lon;
  final int? population;

  /// Только в ответе /cities/nearest — расстояние до центра города.
  final double? distanceKm;

  factory City.fromJson(Map<String, dynamic> json) => City(
        id: json['id'] as String,
        name: json['name'] as String,
        region: json['region'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        population: json['population'] as int?,
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
      );
}

/// Клиентское значение «без ограничения по городу» — в справочнике его нет.
const allRussia = 'Вся Россия';
