import 'order.dart';
import 'order_kind.dart';

/// Сортировка ленты «Заказы рядом». newest — порядок сервера:
/// /orders/available уже отдаёт заказы через latest().
enum NearbySort { newest, soonest, priceDesc }

extension NearbySortX on NearbySort {
  String get label => switch (this) {
    NearbySort.newest => 'Новые',
    NearbySort.soonest => 'Ближе по дате',
    NearbySort.priceDesc => 'Дороже',
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
}

/// Фильтры шторки «Заказов рядом». Считаются на клиенте: /orders/available
/// отдаёт всё одним списком без пагинации и без параметров запроса.
class NearbyFilter {
  const NearbyFilter({
    this.kind,
    this.cities = const {},
    this.when = NearbyWhen.any,
    this.minPrice,
    this.brands = const {},
    this.sort = NearbySort.newest,
  });

  /// null — оба вида.
  final OrderKind? kind;
  final Set<String> cities;
  final NearbyWhen when;

  /// Нижняя граница askingPrice — цены, которую назвал заказчик осмотра.
  final int? minPrice;
  final Set<String> brands;
  final NearbySort sort;

  /// Сколько фильтров включено — число на бейдже кнопки. Сортировка не
  /// фильтр: она ничего не прячет.
  int get activeCount =>
      (kind != null ? 1 : 0) +
      cities.length +
      (when != NearbyWhen.any ? 1 : 0) +
      (minPrice != null ? 1 : 0) +
      brands.length;

  bool get isEmpty => activeCount == 0;

  NearbyFilter copyWith({
    OrderKind? Function()? kind,
    Set<String>? cities,
    NearbyWhen? when,
    int? Function()? minPrice,
    Set<String>? brands,
    NearbySort? sort,
  }) => NearbyFilter(
    kind: kind != null ? kind() : this.kind,
    cities: cities ?? this.cities,
    when: when ?? this.when,
    minPrice: minPrice != null ? minPrice() : this.minPrice,
    brands: brands ?? this.brands,
    sort: sort ?? this.sort,
  );
}

/// Города заказа. У подбора — список cities, у осмотра город есть только
/// в начале адреса («Химки, ул. Ленина, 5»).
List<String> orderCities(Order order) {
  if (order.isInspection) {
    final city = order.address?.split(',').first.trim() ?? '';
    return city.isEmpty ? const [] : [city];
  }
  return order.cities;
}

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
  }
  return result;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
