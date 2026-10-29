import '../models/city.dart';
import 'api_client.dart';

/// Справочник городов. Две реализации, как у CarCatalogRepository:
/// [ApiCityRepository] поверх бекенда и MockCityRepository для виджет-тестов.
abstract class CityRepository {
  /// Города, чьё название начинается с [query]; крупные первыми. Пустой
  /// запрос — крупнейшие города.
  Future<List<City>> search(String query);

  /// Ближайший город в радиусе 50 км или null, если рядом ничего нет.
  Future<City?> nearest(double lat, double lon);
}

/// Кеширует ответы поиска в памяти на всю сессию: справочник не меняется,
/// а при наборе одни и те же префиксы приходят снова. Ошибки не кешируются —
/// «Повторить» снова идёт в сеть.
class ApiCityRepository implements CityRepository {
  ApiCityRepository(this._client);

  final ApiClient _client;
  final Map<String, List<City>> _search = {};

  @override
  Future<List<City>> search(String query) async {
    final q = query.trim().toLowerCase();
    final cached = _search[q];
    if (cached != null) return cached;
    final json = await _client.get(
      q.isEmpty ? '/cities' : '/cities?q=${Uri.encodeQueryComponent(q)}',
    );
    return _search[q] = (json['data'] as List)
        .map((e) => City.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<City?> nearest(double lat, double lon) async {
    final json = await _client.get('/cities/nearest?lat=$lat&lon=$lon');
    final data = json['data'];
    return data == null ? null : City.fromJson(data as Map<String, dynamic>);
  }
}
