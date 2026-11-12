import '../models/car_catalog.dart';
import 'api_client.dart';
import 'json_list.dart';

/// Справочник марок и моделей. Две реализации, как у OrderRepository:
/// [ApiCarCatalogRepository] поверх бекенда и MockCarCatalogRepository
/// для виджет-тестов.
abstract class CarCatalogRepository {
  /// Популярные марки первыми, дальше по алфавиту — порядок задаёт бекенд.
  Future<List<CarMake>> fetchMakes();

  Future<List<CarModel>> fetchModels(String makeId);

  /// Что за машина по ссылке на объявление; null — не узнали.
  Future<ListingGuess?> guessFromListing(String url);
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
    return _makes = List.unmodifiable(
      parseList(json['data'], CarMake.fromJson, what: 'марка'),
    );
  }

  @override
  Future<List<CarModel>> fetchModels(String makeId) async {
    final cached = _models[makeId];
    if (cached != null) return cached;
    final json = await _client.get(
      '/car-makes/${Uri.encodeComponent(makeId)}/models',
    );
    return _models[makeId] = List.unmodifiable(
      parseList(json['data'], CarModel.fromJson, what: 'модель'),
    );
  }

  @override
  Future<ListingGuess?> guessFromListing(String url) async {
    final json = await _client.get(
      '/listing/guess?url=${Uri.encodeQueryComponent(url)}',
    );
    final data = json['data'] as Map<String, dynamic>?;
    return data == null ? null : ListingGuess.fromJson(data);
  }
}
