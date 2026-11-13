import 'package:flutter/foundation.dart';

import '../models/nearby_filter.dart';
import '../models/order_kind.dart';
import '../util/money.dart';
import 'nearby_filter_store.dart';
import 'order_store.dart';

/// Запрос ленты «Заказы рядом» (ревью №16): фильтр шторки, «Мало откликов»,
/// точка устройства для «Ближе ко мне» и расстояния. Фильтрует и листает
/// сервер — контроллер лишь решает, когда и с чем звать
/// `OrderStore.loadAvailableOrders`. Шторки, отклик и переходы — у экрана.
///
/// Экран создаёт контроллер в `initState` и зовёт [start], закрывает —
/// [dispose].
class NearbyFeedController extends ChangeNotifier {
  /// [filters] — общий стор фильтров; null — свой, без сохранения между
  /// запусками (закрывается вместе с контроллером).
  NearbyFeedController(this.store, {NearbyFilterStore? filters})
    : filters = filters ?? NearbyFilterStore(),
      _ownsFilters = filters == null;

  final OrderStore store;
  final NearbyFilterStore filters;
  final bool _ownsFilters;

  bool _fewResponsesOnly = false;
  (double, double)? _here;
  bool _nearUnavailable = false;

  /// Параметры последнего запроса ленты: стор фильтров уведомляет и без
  /// смены фильтра (загрузка из хранилища, город по GPS) — лишний запрос
  /// не шлём.
  String? _lastQuery;

  /// Номер последнего [reload]: пока он ждал геопозицию, мог начаться
  /// следующий — устаревший не шлёт запрос.
  int _reloadToken = 0;

  bool _disposed = false;

  /// Только заказы с малым числом откликов.
  bool get fewResponsesOnly => _fewResponsesOnly;

  /// Точка устройства для «· 8 км»; null — без геопозиции, только город.
  (double, double)? get here => _here;

  /// «Ближе ко мне», а геопозиции нет — лента пришла «новыми», об этом
  /// строка над списком.
  bool get nearUnavailable => _nearUnavailable;

  /// Подписка на фильтры, первая страница и точка устройства.
  void start() {
    filters.addListener(reload);
    reload();
    locate();
  }

  /// Фильтрует и листает сервер: сменился фильтр — первая страница заново.
  /// «Ближе ко мне» — с точкой устройства: удачу локатор кеширует, ждём её
  /// только в первый раз.
  Future<void> reload() async {
    final token = ++_reloadToken;
    var filter = filters.filter;
    final nearest = filter.sort == NearbySort.nearest;
    if (nearest) {
      final here = _here ?? await store.locator?.position();
      if (_disposed || token != _reloadToken) return;
      if (here != null) _here = here;
      filter = filter.copyWith(near: () => here);
    }
    final unavailable = nearest && filter.near == null;
    if (unavailable != _nearUnavailable) {
      _nearUnavailable = unavailable;
      notifyListeners();
    }
    final query = filter.toQuery(fewResponses: _fewResponsesOnly);
    if (query == _lastQuery) return;
    _lastQuery = query;
    store.loadAvailableOrders(filter: filter, fewResponses: _fewResponsesOnly);
  }

  void setFewResponses(bool value) {
    _fewResponsesOnly = value;
    notifyListeners();
    reload();
  }

  Future<void> locate() async {
    final here = await store.locator?.position();
    if (here == null || _disposed) return;
    _here = here;
    notifyListeners();
  }

  /// Город по GPS, если ленту опустошил только он, — тогда пустая лента
  /// объясняется городом и предлагает все города, а не «сбросить фильтры».
  String? get onlyAutoCity {
    final f = filters.filter;
    if (!filters.isAutoCity || _fewResponsesOnly) return null;
    if (f.cities.length != 1 || f.activeCount != 1) return null;
    return f.cities.first;
  }

  /// Снять всё, кроме сортировки и города по GPS.
  void resetFilters() {
    _fewResponsesOnly = false;
    notifyListeners();
    filters.set(
      NearbyFilter(sort: filters.filter.sort, cities: filters.gpsCities),
    );
    // фильтр шторки мог и не измениться — «Мало откликов» тоже сброшено
    reload();
  }

  /// Показать все города: снять город фильтра.
  void showAllCities() =>
      filters.set(filters.filter.copyWith(cities: const {}));

  /// Включённые фильтры шторки — чипами с крестиком под шапкой, чтобы было
  /// видно, почему список короткий. Вторая часть — фильтр без этого чипа.
  List<(String, NearbyFilter)> activeChips() {
    final f = filters.filter;
    return [
      if (f.kind != null)
        (
          f.kind!.isInspection ? 'Осмотр' : 'Подбор',
          f.copyWith(kind: () => null),
        ),
      for (final city in f.cities)
        (city, f.copyWith(cities: {...f.cities}..remove(city))),
      if (f.when != NearbyWhen.any)
        (f.when.label, f.copyWith(when: NearbyWhen.any)),
      if (f.minPrice != null)
        ('от ${money(f.minPrice!)} ₽', f.copyWith(minPrice: () => null)),
      for (final brand in f.brands)
        (brand, f.copyWith(brands: {...f.brands}..remove(brand))),
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    filters.removeListener(reload);
    if (_ownsFilters) filters.dispose();
    super.dispose();
  }
}
