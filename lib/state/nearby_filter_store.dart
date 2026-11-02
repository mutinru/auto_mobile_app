import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/nearby_filter.dart';
import 'city_locator.dart';

/// Фильтры и сортировка экрана «Заказы рядом». Переживают перезапуск и
/// уход в другой раздел — все, кроме «Когда» ([NearbyFilter.toJson]):
/// подборщик обычно смотрит одно и то же.
/// Лежат в том же защищённом хранилище, что тема ([ThemeController]), —
/// отдельный пакет настроек не тянем. Формат — [NearbyFilter.toJson].
///
/// Пока пользователь ни разу не менял фильтр (в хранилище пусто), город
/// подставляется по GPS — и **не** сохраняется: переехал — при следующем
/// запуске подхватится новый. Любая правка пользователя ([set]), включая
/// «Сбросить фильтры» и снятый чип города, сохраняется и с этого момента
/// GPS в фильтр не вмешивается.
class NearbyFilterStore extends ChangeNotifier {
  /// Без сохранения и без города по GPS — для виджет-тестов и экрана,
  /// которому стор не передали.
  NearbyFilterStore() : _read = null, _write = null, _locator = null;

  /// С сохранением в хранилище устройства. [locator] — город по GPS, пока
  /// пользователь не выбрал фильтр сам.
  factory NearbyFilterStore.persistent({CityLocator? locator}) {
    const storage = FlutterSecureStorage();
    return NearbyFilterStore.withStorage(
      () => storage.read(key: _key),
      (value) => storage.write(key: _key, value: value),
      locator,
    );
  }

  /// Хранилище колбэками — чтобы тесты обходились без платформенного плагина.
  @visibleForTesting
  NearbyFilterStore.withStorage(this._read, this._write, [this._locator]);

  static const _key = 'nearby_filter';
  final Future<String?> Function()? _read;
  final Future<void> Function(String value)? _write;
  final CityLocator? _locator;

  NearbyFilter _filter = const NearbyFilter();
  NearbyFilter get filter => _filter;

  /// Фильтр выбрал пользователь: нашёлся в хранилище или задан через [set].
  bool _userChosen = false;

  /// Город в фильтре подставлен по GPS, а не выбран пользователем.
  bool get isAutoCity => _autoCity;
  bool _autoCity = false;

  bool _disposed = false;

  Future<void> load() async {
    final read = _read;
    if (read == null) return;
    try {
      final raw = await read();
      if (raw != null && !_userChosen) {
        _userChosen = true;
        _filter = NearbyFilter.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        _notify();
      }
    } catch (_) {
      // недоступное или битое хранилище — начинаем без фильтров
    }
    await _applyDetectedCity();
  }

  /// Город по GPS — только пока пользователь ничего не выбирал. Проверка
  /// повторяется после ожидания: пока шёл GPS, он мог уже открыть шторку.
  Future<void> _applyDetectedCity() async {
    final locator = _locator;
    if (locator == null || _userChosen) return;
    final city = await locator.detect();
    if (city == null || _userChosen || _disposed) return;
    _filter = _filter.copyWith(cities: {city.name});
    _autoCity = true;
    _notify();
  }

  Future<void> set(NearbyFilter next) async {
    _filter = next;
    _userChosen = true;
    _autoCity = false;
    _notify();
    final write = _write;
    if (write == null) return;
    try {
      await write(jsonEncode(next.toJson()));
    } catch (_) {
      // не сохранилось — фильтр всё равно работает до перезапуска
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
