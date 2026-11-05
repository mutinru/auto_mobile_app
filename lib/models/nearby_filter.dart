import '../util/geo.dart';
import 'order.dart';
import 'order_kind.dart';

/// Сортировка ленты «Заказы рядом» — делает сервер. [apiValue] — зеркало
/// AvailableOrders::SORTS на бекенде.
enum NearbySort { newest, soonest, priceDesc, nearest }

extension NearbySortX on NearbySort {
  String get label => switch (this) {
    NearbySort.newest => 'Новые',
    NearbySort.soonest => 'Ближе по дате',
    NearbySort.priceDesc => 'Дороже',
    NearbySort.nearest => 'Ближе ко мне',
  };

  String get apiValue => switch (this) {
    NearbySort.newest => 'newest',
    NearbySort.soonest => 'soonest',
    NearbySort.priceDesc => 'price_desc',
    NearbySort.nearest => 'nearest',
  };
}

/// Окно даты осмотра. Дата есть только у осмотра.
enum NearbyWhen { any, today, tomorrow, week }

extension NearbyWhenX on NearbyWhen {
  String get label => switch (this) {
    NearbyWhen.any => 'Любая',
    NearbyWhen.today => 'Сегодня',
    NearbyWhen.tomorrow => 'Завтра',
    NearbyWhen.week => 'На неделе',
  };

  /// Зеркало AvailableOrders::WHEN на бекенде; any — параметра нет.
  String? get apiValue => switch (this) {
    NearbyWhen.any => null,
    NearbyWhen.today => 'today',
    NearbyWhen.tomorrow => 'tomorrow',
    NearbyWhen.week => 'week',
  };
}

/// Фильтры шторки «Заказов рядом». Фильтрует и сортирует сервер
/// (/orders/available, параметры — [toQuery]); [applyNearbyFilter] — та же
/// логика для мок-репозитория.
class NearbyFilter {
  const NearbyFilter({
    this.kind,
    this.cities = const {},
    this.when = NearbyWhen.any,
    this.minPrice,
    this.brands = const {},
    this.sort = NearbySort.newest,
    this.near,
  });

  /// null — оба вида.
  final OrderKind? kind;
  final Set<String> cities;
  final NearbyWhen when;

  /// Нижняя граница askingPrice — цены, которую назвал заказчик осмотра.
  final int? minPrice;
  final Set<String> brands;
  final NearbySort sort;

  /// Точка зрителя (широта, долгота) для [NearbySort.nearest] — её ставит
  /// экран ленты из геопозиции. Не сохраняется ([toJson]): переехал — и
  /// старая точка врала бы.
  final (double, double)? near;

  /// Сколько фильтров включено — число на бейдже кнопки. Сортировка не
  /// фильтр: она ничего не прячет.
  int get activeCount =>
      (kind != null ? 1 : 0) +
      cities.length +
      (when != NearbyWhen.any ? 1 : 0) +
      (minPrice != null ? 1 : 0) +
      brands.length;

  bool get isEmpty => activeCount == 0;

  /// Параметры /orders/available и /orders/available/count (без «?»).
  /// «Когда» уходит на сервер, хотя и не сохраняется ([toJson]).
  /// [fewResponses] — быстрый фильтр «Мало откликов» с экрана.
  String toQuery({bool fewResponses = false}) {
    String enc(String v) => Uri.encodeQueryComponent(v);
    return [
      if (kind != null) 'kind=${kind!.apiValue}',
      for (final city in cities.toList()..sort()) 'cities[]=${enc(city)}',
      for (final brand in brands.toList()..sort()) 'brands[]=${enc(brand)}',
      if (when.apiValue != null) 'when=${when.apiValue}',
      if (minPrice != null) 'min_price=$minPrice',
      if (fewResponses) 'few_responses=1',
      if (sort != NearbySort.newest) 'sort=${sort.apiValue}',
      // точку шлём только туда, где она нужна, и с точностью ~100 м
      if (sort == NearbySort.nearest && near != null) ...[
        'lat=${near!.$1.toStringAsFixed(3)}',
        'lon=${near!.$2.toStringAsFixed(3)}',
      ],
    ].join('&');
  }

  /// Для хранилища устройства ([NearbyFilterStore]). Энамы — по имени:
  /// переименование значения сбросит сохранённое поле к умолчанию, а не
  /// уронит разбор. «Когда» не сохраняется намеренно: «Сегодня» назавтра
  /// прятало бы всю ленту — после перезапуска оно снова «Любая».
  Map<String, dynamic> toJson() => {
    'kind': kind?.apiValue,
    'cities': cities.toList(),
    'min_price': minPrice,
    'brands': brands.toList(),
    'sort': sort.name,
  };

  /// Неизвестные и битые поля молча берут значение по умолчанию: старая
  /// запись (только kind и cities) тоже разбирается.
  factory NearbyFilter.fromJson(Map<String, dynamic> json) {
    T? byName<T extends Enum>(List<T> values, Object? name) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    Set<String> strings(Object? list) =>
        list is List ? {...list.whereType<String>()} : const {};

    final kind = json['kind'];
    final minPrice = json['min_price'];
    return NearbyFilter(
      kind: kind is String ? orderKindFromApi(kind) : null,
      cities: strings(json['cities']),
      minPrice: minPrice is int ? minPrice : null,
      brands: strings(json['brands']),
      sort: byName(NearbySort.values, json['sort']) ?? NearbySort.newest,
    );
  }

  NearbyFilter copyWith({
    OrderKind? Function()? kind,
    Set<String>? cities,
    NearbyWhen? when,
    int? Function()? minPrice,
    Set<String>? brands,
    NearbySort? sort,
    (double, double)? Function()? near,
  }) => NearbyFilter(
    kind: kind != null ? kind() : this.kind,
    cities: cities ?? this.cities,
    when: when ?? this.when,
    minPrice: minPrice != null ? minPrice() : this.minPrice,
    brands: brands ?? this.brands,
    sort: sort ?? this.sort,
    near: near != null ? near() : this.near,
  );
}

/// Города заказа: у подбора — где искать, у осмотра — один, где машина.
List<String> orderCities(Order order) => order.cities;

/// Города из загруженных заказов — варианты для шторки.
List<String> cityOptions(List<Order> orders) =>
    {for (final o in orders) ...orderCities(o)}.toList()..sort();

List<String> brandOptions(List<Order> orders) =>
    {for (final o in orders) o.brand}.toList()..sort();

/// Применить фильтр и сортировку. [now] — для тестов.
List<Order> applyNearbyFilter(
  List<Order> orders,
  NearbyFilter filter, {
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());

  bool inWindow(DateTime? date) {
    if (date == null) return false;
    final days = _dateOnly(date).difference(today).inDays;
    return switch (filter.when) {
      NearbyWhen.any => true,
      NearbyWhen.today => days == 0,
      NearbyWhen.tomorrow => days == 1,
      NearbyWhen.week => days >= 0 && days < 7,
    };
  }

  final result = orders.where((o) {
    if (filter.kind != null && o.kind != filter.kind) return false;
    if (filter.cities.isNotEmpty &&
        !orderCities(o).any(filter.cities.contains)) {
      return false;
    }
    if (filter.brands.isNotEmpty && !filter.brands.contains(o.brand)) {
      return false;
    }
    // даты и цены у подбора нет — под такими фильтрами он не показывается,
    // иначе «Сегодня» выдавал бы заказы без всякой даты
    if (filter.when != NearbyWhen.any && !inWindow(o.inspectOn)) return false;
    if (filter.minPrice != null &&
        (o.askingPrice == null || o.askingPrice! < filter.minPrice!)) {
      return false;
    }
    return true;
  }).toList();

  // List.sort нестабилен — при равенстве держим исходный порядок
  final index = {for (var i = 0; i < orders.length; i++) orders[i].id: i};
  int byIndex(Order a, Order b) => index[a.id]!.compareTo(index[b.id]!);

  switch (filter.sort) {
    case NearbySort.newest:
      break;
    case NearbySort.soonest:
      result.sort((a, b) {
        final x = a.inspectOn, y = b.inspectOn;
        if (x == null && y == null) return byIndex(a, b);
        if (x == null) return 1;
        if (y == null) return -1;
        final c = x.compareTo(y);
        return c != 0 ? c : byIndex(a, b);
      });
    case NearbySort.priceDesc:
      result.sort((a, b) {
        final x = a.askingPrice, y = b.askingPrice;
        if (x == null && y == null) return byIndex(a, b);
        if (x == null) return 1;
        if (y == null) return -1;
        final c = y.compareTo(x);
        return c != 0 ? c : byIndex(a, b);
      });
    case NearbySort.nearest:
      final near = filter.near;
      if (near == null) break;
      double? km(Order o) => o.lat == null || o.lon == null
          ? null
          : distanceKm(near.$1, near.$2, o.lat!, o.lon!);
      result.sort((a, b) {
        final x = km(a), y = km(b);
        if (x == null && y == null) return byIndex(a, b);
        if (x == null) return 1;
        if (y == null) return -1;
        final c = x.compareTo(y);
        return c != 0 ? c : byIndex(a, b);
      });
  }
  return result;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
