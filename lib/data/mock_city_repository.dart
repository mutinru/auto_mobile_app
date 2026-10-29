import '../models/car_catalog.dart';
import '../models/city.dart';
import 'city_repository.dart';

/// Маленький справочник для виджет-тестов без бекенда. [fail] заставляет
/// загрузку падать — проверить ручной ввод без сети.
class MockCityRepository implements CityRepository {
  MockCityRepository({this.fail = false});

  bool fail;

  static const cities = [
    City(id: 'msk', name: 'Москва', region: 'Москва', lat: 55.754, lon: 37.620, population: 11514330),
    City(id: 'spb', name: 'Санкт-Петербург', region: 'Санкт-Петербург', lat: 59.939, lon: 30.316, population: 4848742),
    City(id: 'kzn', name: 'Казань', region: 'Респ Татарстан', lat: 55.794, lon: 49.111, population: 1143535),
    City(id: 'khimki', name: 'Химки', region: 'Московская обл', lat: 55.889, lon: 37.445, population: 207425),
    City(id: 'mytishchi', name: 'Мытищи', region: 'Московская обл', lat: 55.911, lon: 37.731, population: 173160),
    City(id: 'orel', name: 'Орёл', region: 'Орловская обл', lat: 52.970, lon: 36.064, population: 317854),
  ];

  @override
  Future<List<City>> search(String query) async {
    if (fail) throw Exception('нет сети');
    final q = normalizeSearch(query.trim());
    return cities.where((c) => normalizeSearch(c.name).startsWith(q)).toList();
  }

  /// Без геометрии: ближайший по сумме разниц координат, в пределах ~0.5°.
  @override
  Future<City?> nearest(double lat, double lon) async {
    if (fail) throw Exception('нет сети');
    City? best;
    var bestD = 0.5;
    for (final c in cities) {
      final d = (c.lat - lat).abs() + (c.lon - lon).abs();
      if (d < bestD) {
        best = c;
        bestD = d;
      }
    }
    return best;
  }
}
