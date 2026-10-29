import '../models/car_catalog.dart';
import 'car_catalog_repository.dart';

/// Маленький справочник для виджет-тестов без бекенда. [fail] заставляет
/// загрузку падать — проверить ручной ввод без сети.
class MockCarCatalogRepository implements CarCatalogRepository {
  MockCarCatalogRepository({this.fail = false});

  bool fail;

  static const _makes = [
    CarMake(id: 'TOYOTA', name: 'Toyota', nameRu: 'Тойота', popular: true),
    CarMake(id: 'VAZ', name: 'Lada (ВАЗ)', nameRu: 'Лада', popular: true),
    CarMake(id: 'KIA', name: 'Kia', nameRu: 'Киа', popular: true),
    CarMake(id: 'ABARTH', name: 'Abarth', nameRu: 'Абарт'),
  ];

  static const _models = {
    'TOYOTA': [
      CarModel(id: 'TOYOTA_CAMRY', name: 'Camry', nameRu: 'Камри', yearFrom: 1982, yearTo: 2026),
      CarModel(id: 'TOYOTA_RAV4', name: 'RAV4', nameRu: 'РАВ4', yearFrom: 1994, yearTo: 2026),
    ],
    'VAZ': [
      CarModel(id: 'VAZ_GRANTA', name: 'Granta', nameRu: 'Гранта', yearFrom: 2011, yearTo: 2026),
      CarModel(id: 'VAZ_VESTA', name: 'Vesta', nameRu: 'Веста', yearFrom: 2015, yearTo: 2026),
    ],
    'KIA': [
      CarModel(id: 'KIA_RIO', name: 'Rio', nameRu: 'Рио', yearFrom: 2000, yearTo: 2026),
      CarModel(id: 'KIA_SPORTAGE', name: 'Sportage', nameRu: 'Спортейдж', yearFrom: 1993, yearTo: 2026),
    ],
    'ABARTH': [
      CarModel(id: 'ABARTH_500', name: '500', nameRu: '500', yearFrom: 2008, yearTo: 2024),
    ],
  };

  @override
  Future<List<CarMake>> fetchMakes() async {
    if (fail) throw Exception('нет сети');
    return _makes;
  }

  @override
  Future<List<CarModel>> fetchModels(String makeId) async {
    if (fail) throw Exception('нет сети');
    return _models[makeId] ?? const [];
  }
}
