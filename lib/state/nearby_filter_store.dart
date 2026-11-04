import 'dart:async';
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
/// Пока пользователь сам не выбирал город, он подставляется по GPS — и
/// **не** сохраняется: переехал — при следующем запуске подхватится новый.
/// Город по GPS — значение по умолчанию: правки других фильтров его не
/// трогают, а «Сбросить» возвращает к нему. Выбором считается только набор
/// городов, отличный от города по GPS (другой город, снятый чип, «Показать
/// все города»), — такой выбор сохраняется, и GPS в фильтр не вмешивается,
/// пока набор снова не совпадёт с городом по GPS.
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

  /// Город выбрал пользователь (сохранено как `city_chosen`) — тогда GPS
  /// фильтр не трогает. Прочие сохранённые поля на это не влияют.
  bool _cityChosen = false;

  /// Город по GPS, когда он известен (пусто — ещё не определён или GPS не
  /// дал точку). Его подставляет «Сбросить».
  Set<String> get gpsCities => _gpsCities;
  Set<String> _gpsCities = const {};

  /// Город в фильтре подставлен по GPS, а не выбран пользователем.
  bool get isAutoCity => _autoCity;
  bool _autoCity = false;

  /// Был [set] — сохранённое при чтении уже не нужно.
  bool _touched = false;

  bool _disposed = false;

  Future<void> load() async {
    final read = _read;
    if (read == null) return;
    try {
      final raw = await read();
      // set() мог успеть раньше чтения — тогда сохранённое уже устарело
      if (raw != null && !_touched) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _filter = NearbyFilter.fromJson(json);
        // запись до city_chosen: выбранный город был, только если он в ней есть
        final chosen = json['city_chosen'];
        _cityChosen = chosen is bool ? chosen : _filter.cities.isNotEmpty;
        _notify();
      }
    } catch (_) {
      // недоступное или битое хранилище — начинаем без фильтров
    }
    await _applyDetectedCity();
  }

  /// Определяет город по GPS всегда — он нужен «Сбросить», — а в фильтр
  /// подставляет, только пока пользователь не выбрал город сам. Проверка
  /// после ожидания: пока шёл GPS, он мог уже выбрать.
  Future<void> _applyDetectedCity() async {
    final locator = _locator;
    if (locator == null) return;
    final city = await locator.detect();
    if (city == null || _disposed) return;
    _gpsCities = {city.name};
    if (_cityChosen) return;
    _filter = _filter.copyWith(cities: _gpsCities);
    _autoCity = true;
    _notify();
  }

  /// Новый фильтр от пользователя. [from] — фильтр, от которого он
  /// отталкивался (что было в шторке при открытии): изменились ли города,
  /// решаем по нему — пока шторка открыта, GPS мог подставить город, и
  /// без [from] его отсутствие в [next] сочлось бы снятым чипом.
  Future<void> set(NearbyFilter next, {NearbyFilter? from}) async {
    _touched = true;
    if (!_cityChosen && setEquals(next.cities, (from ?? _filter).cities)) {
      // город не трогали — остаётся тот, что дал GPS (или пока никакого)
      next = next.copyWith(cities: _filter.cities);
    } else {
      // совпал с городом по GPS (в том числе после «Сбросить») — снова
      // умолчание, а не выбор
      _cityChosen = !setEquals(next.cities, _gpsCities);
    }
    _autoCity = !_cityChosen && next.cities.isNotEmpty;
    _filter = next;
    _notify();
    // город по GPS ещё не определён — подставится, когда определится
    if (!_cityChosen && next.cities.isEmpty) unawaited(_applyDetectedCity());
    final write = _write;
    if (write == null) return;
    try {
      // город по GPS не сохраняем: при следующем запуске определится заново
      final saved = _cityChosen ? next : next.copyWith(cities: const {});
      await write(
        jsonEncode({...saved.toJson(), 'city_chosen': _cityChosen}),
      );
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
