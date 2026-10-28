import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/nearby_filter.dart';
import '../models/order_kind.dart';

/// Фильтры экрана «Заказы рядом». Вид заказа и города переживают
/// перезапуск: подборщик обычно работает в одном городе. Лежат в том же
/// защищённом хранилище, что тема ([ThemeController]), — отдельный пакет
/// настроек не тянем. Остальное живёт, пока открыт экран.
class NearbyFilterStore extends ChangeNotifier {
  /// Без сохранения — для виджет-тестов и экрана, которому стор не передали.
  NearbyFilterStore() : _storage = null;

  /// С сохранением в хранилище устройства.
  NearbyFilterStore.persistent() : _storage = const FlutterSecureStorage();

  static const _key = 'nearby_filter';
  final FlutterSecureStorage? _storage;

  NearbyFilter _filter = const NearbyFilter();
  NearbyFilter get filter => _filter;

  Future<void> load() async {
    final storage = _storage;
    if (storage == null) return;
    try {
      final raw = await storage.read(key: _key);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final kind = json['kind'] as String?;
      _filter = _filter.copyWith(
        kind: () => kind == null ? null : orderKindFromApi(kind),
        cities: {...?(json['cities'] as List?)?.cast<String>()},
      );
      notifyListeners();
    } catch (_) {
      // недоступное или битое хранилище — начинаем без фильтров
    }
  }

  Future<void> set(NearbyFilter next) async {
    _filter = next;
    notifyListeners();
    final storage = _storage;
    if (storage == null) return;
    try {
      await storage.write(
        key: _key,
        value: jsonEncode({
          'kind': next.kind?.apiValue,
          'cities': next.cities.toList(),
        }),
      );
    } catch (_) {
      // не сохранилось — фильтр всё равно работает до перезапуска
    }
  }
}
