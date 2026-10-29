import '../models/car_catalog.dart';
import 'api_client.dart';

/// Справочник марок и моделей. Две реализации, как у OrderRepository:
/// [ApiCarCatalogRepository] поверх бекенда и MockCarCatalogRepository
/// для виджет-тестов.
abstract class CarCatalogRepository {
  /// Популярные марки первыми, дальше по алфавиту — порядок задаёт бекенд.
  Future<List<CarMake>> fetchMakes();

  Future<List<CarModel>> fetchModels(String makeId);
}

/// Кеширует ответы в памяти на всю сессию: справочник меняется редко,
/// а лист выбора открывают на каждой форме. Ошибки не кешируются —
/// «Повторить» снова идёт в сеть.
class ApiCarCatalogRepository implements CarCatalogRepository {
  ApiCarCatalogRepository(this._client);

  final ApiClient _client;

  List<CarMake>? _makes;
  final Map<String, List<CarModel>> _models = {};

  @override
  Future<List<CarMake>> fetchMakes() async {
    if (_makes != null) return _makes!;
    final json = await _client.get('/car-makes');
    return _makes = (json['data'] as List)
        .map((e) => CarMake.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<CarModel>> fetchModels(String makeId) async {
    final cached = _models[makeId];
    if (cached != null) return cached;
    final json = await _client.get('/car-makes/${Uri.encodeComponent(makeId)}/models');
    return _models[makeId] = (json['data'] as List)
        .map((e) => CarModel.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
