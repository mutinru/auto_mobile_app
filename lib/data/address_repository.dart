import 'api_client.dart';

/// Подсказка адреса: [value] — без города (его выбирают отдельно),
/// [unrestrictedValue] — полный адрес, по нему [AddressRepository.resolve]
/// находит точку.
class AddressSuggestion {
  const AddressSuggestion({required this.value, required this.unrestrictedValue});

  final String value;
  final String unrestrictedValue;

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) => AddressSuggestion(
        value: json['value'] as String,
        unrestrictedValue: json['unrestricted_value'] as String,
      );
}

/// Точка выбранной подсказки; [precision] — qc_geo DaData (0 — дом …
/// 5 — не определено).
class AddressPoint {
  const AddressPoint({required this.lat, required this.lon, required this.precision});

  final double lat;
  final double lon;
  final int precision;
}

/// Подсказки адреса осмотра (бекенд ходит в DaData). Только подсказки:
/// адрес принимается и своим текстом, поэтому ни один метод не бросает —
/// без сети, без ключа или с исчерпанным лимитом ответ просто пустой.
abstract class AddressRepository {
  /// Адреса в пределах города [cityId] (fias_id из справочника) или везде.
  Future<List<AddressSuggestion>> suggest(String query, {String? cityId});

  Future<AddressPoint?> resolve(AddressSuggestion suggestion);
}

/// Кеширует удачные ответы в памяти на всю сессию: при наборе и стирании
/// одни и те же префиксы приходят снова, а у DaData суточный лимит.
class ApiAddressRepository implements AddressRepository {
  ApiAddressRepository(this._client);

  final ApiClient _client;
  final Map<String, List<AddressSuggestion>> _suggest = {};

  @override
  Future<List<AddressSuggestion>> suggest(String query, {String? cityId}) async {
    final q = query.trim();
    final key = '${cityId ?? ''}|${q.toLowerCase()}';
    final cached = _suggest[key];
    if (cached != null) return cached;
    try {
      final json = await _client.get(
        '/addresses/suggest?q=${Uri.encodeQueryComponent(q)}'
        '${cityId == null ? '' : '&city_id=${Uri.encodeQueryComponent(cityId)}'}',
      );
      final list = (json['data'] as List)
          .map((e) => AddressSuggestion.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      // пустой ответ может значить «кончился лимит» — его не запоминаем
      if (list.isNotEmpty) _suggest[key] = list;
      return list;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<AddressPoint?> resolve(AddressSuggestion suggestion) async {
    try {
      final json = await _client.get(
        '/addresses/resolve?value=${Uri.encodeQueryComponent(suggestion.unrestrictedValue)}',
      );
      final data = json['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      return AddressPoint(
        lat: (data['lat'] as num).toDouble(),
        lon: (data['lon'] as num).toDouble(),
        precision: data['precision'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Для виджет-тестов: подсказки по началу строки из маленького списка.
class MockAddressRepository implements AddressRepository {
  MockAddressRepository({this.streets = const ['ул Ленина, д 5', 'ул Ленинградская, д 12']});

  final List<String> streets;

  @override
  Future<List<AddressSuggestion>> suggest(String query, {String? cityId}) async {
    final q = query.trim().toLowerCase();
    return [
      for (final s in streets)
        if (s.toLowerCase().contains(q))
          AddressSuggestion(value: s, unrestrictedValue: '${cityId ?? ''}, $s'),
    ];
  }

  @override
  Future<AddressPoint?> resolve(AddressSuggestion suggestion) async =>
      const AddressPoint(lat: 55.8897, lon: 37.4449, precision: 0);
}
