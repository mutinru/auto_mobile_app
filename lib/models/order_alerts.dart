import 'order_kind.dart';

/// Подписка исполнителя на новые заказы (PUT /me/order-alerts): пуш, когда
/// в одном из [cities] публикуют заказ вида из [kinds]. Кому слать, тихие
/// часы и лимит решает сервер. Города — по имени, как `Order.cities` и
/// фильтр ленты.
class OrderAlerts {
  const OrderAlerts({
    this.cities = const {},
    this.kinds = const {OrderKind.selection, OrderKind.inspection},
  });

  /// Не больше стольких городов — зеркало NewOrderAlerts::MAX_CITIES.
  static const maxCities = 10;

  final Set<String> cities;
  final Set<OrderKind> kinds;

  /// Пустой список городов — подписка выключена.
  bool get isOn => cities.isNotEmpty;

  bool covers(String city) => cities.contains(city);

  /// «Казань, Москва» или «Выключено» — подпись в настройках.
  String get summary {
    if (!isOn) return 'Выключено';
    final names = (cities.toList()..sort()).join(', ');
    if (kinds.length == OrderKind.values.length) return names;
    return '$names · ${kinds.single.isInspection ? 'только осмотры' : 'только подборы'}';
  }

  OrderAlerts copyWith({Set<String>? cities, Set<OrderKind>? kinds}) =>
      OrderAlerts(cities: cities ?? this.cities, kinds: kinds ?? this.kinds);

  Map<String, dynamic> toJson() => {
    'cities': cities.toList()..sort(),
    'kinds': [for (final k in kinds) k.apiValue],
  };

  /// Нет поля (старый сервер) — выключена, оба вида.
  factory OrderAlerts.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OrderAlerts();
    final kinds = {
      for (final k in (json['kinds'] as List<dynamic>? ?? const []))
        if (k is String) orderKindFromApi(k),
    };
    return OrderAlerts(
      cities: {
        for (final c in (json['cities'] as List<dynamic>? ?? const []))
          if (c is String) c,
      },
      kinds: kinds.isEmpty
          ? const {OrderKind.selection, OrderKind.inspection}
          : kinds,
    );
  }
}
