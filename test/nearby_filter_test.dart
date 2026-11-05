import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/models/nearby_filter.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/widgets/nearby_filter_sheet.dart';

void main() {
  final now = DateTime(2026, 10, 22, 15);
  const customer = UserSummary(id: 1, name: 'Андрей С.');

  Order inspection(
    int id, {
    String? city,
    DateTime? on,
    int? price,
    String brand = 'Kia',
    double? lat,
    double? lon,
  }) => Order(
    id: id,
    kind: OrderKind.inspection,
    status: OrderStatus.awaitingExecutor,
    brand: brand,
    model: 'Rio',
    customer: customer,
    cities: [?city],
    inspectOn: on,
    askingPrice: price,
    lat: lat,
    lon: lon,
  );

  Order selection(
    int id, {
    List<String> cities = const [],
    String brand = 'Volkswagen',
  }) => Order(
    id: id,
    status: OrderStatus.awaitingExecutor,
    brand: brand,
    model: 'Tiguan',
    customer: customer,
    cities: cities,
  );

  final orders = [
    selection(1, cities: ['Москва', 'Химки']),
    inspection(
      2,
      city: 'Химки',
      on: DateTime(2026, 10, 22),
      price: 4000,
    ),
    inspection(
      3,
      city: 'Москва',
      on: DateTime(2026, 10, 23),
      price: 3000,
      brand: 'BMW',
    ),
    inspection(
      4,
      city: 'Мытищи',
      on: DateTime(2026, 11, 5),
      price: 5000,
    ),
  ];

  List<int> ids(NearbyFilter f) =>
      applyNearbyFilter(orders, f, now: now).map((o) => o.id).toList();

  test('без фильтра — всё в порядке сервера', () {
    expect(ids(const NearbyFilter()), [1, 2, 3, 4]);
  });

  test('вид заказа', () {
    expect(ids(const NearbyFilter(kind: OrderKind.selection)), [1]);
    expect(ids(const NearbyFilter(kind: OrderKind.inspection)), [2, 3, 4]);
  });

  test('город берётся из cities у обоих видов заказа', () {
    expect(ids(const NearbyFilter(cities: {'Химки'})), [1, 2]);
    expect(ids(const NearbyFilter(cities: {'Мытищи', 'Москва'})), [1, 3, 4]);
    expect(cityOptions(orders), ['Москва', 'Мытищи', 'Химки']);
  });

  test('«Когда» и «Оплата от» отсекают подбор — у него нет даты и цены', () {
    expect(ids(const NearbyFilter(when: NearbyWhen.today)), [2]);
    expect(ids(const NearbyFilter(when: NearbyWhen.tomorrow)), [3]);
    expect(ids(const NearbyFilter(when: NearbyWhen.week)), [2, 3]);
    expect(ids(const NearbyFilter(minPrice: 4000)), [2, 4]);
  });

  test('марка', () {
    expect(ids(const NearbyFilter(brands: {'BMW', 'Volkswagen'})), [1, 3]);
  });

  test('сортировки: заказы без даты и цены уходят в конец', () {
    expect(ids(const NearbyFilter(sort: NearbySort.soonest)), [2, 3, 4, 1]);
    expect(ids(const NearbyFilter(sort: NearbySort.priceDesc)), [4, 2, 3, 1]);
  });

  test('счётчик фильтров не учитывает сортировку', () {
    expect(const NearbyFilter(sort: NearbySort.priceDesc).activeCount, 0);
    expect(
      const NearbyFilter(
        kind: OrderKind.inspection,
        cities: {'А', 'Б'},
        minPrice: 1,
      ).activeCount,
      4,
    );
  });

  test('склонение в кнопке шторки', () {
    expect(ordersCount(1), '1 заказ');
    expect(ordersCount(3), '3 заказа');
    expect(ordersCount(11), '11 заказов');
    expect(ordersCount(22), '22 заказа');
    expect(ordersCount(25), '25 заказов');
  });

  test('сохранение: фильтры и сортировка переживают JSON, «Когда» — нет', () {
    const filter = NearbyFilter(
      kind: OrderKind.inspection,
      cities: {'Казань', 'Москва'},
      when: NearbyWhen.week,
      minPrice: 12000,
      brands: {'Kia'},
      sort: NearbySort.priceDesc,
    );
    final restored = NearbyFilter.fromJson(
      jsonDecode(jsonEncode(filter.toJson())) as Map<String, dynamic>,
    );
    expect(restored.kind, OrderKind.inspection);
    expect(restored.cities, {'Казань', 'Москва'});
    expect(restored.when, NearbyWhen.any);
    expect(restored.minPrice, 12000);
    expect(restored.brands, {'Kia'});
    expect(restored.sort, NearbySort.priceDesc);
  });

  test('сохранение: старая и битая запись берут значения по умолчанию', () {
    final old = NearbyFilter.fromJson({
      'kind': 'selection',
      'cities': ['Казань'],
      'when': 'week',
    });
    expect(old.kind, OrderKind.selection);
    expect(old.cities, {'Казань'});
    expect(old.when, NearbyWhen.any);
    expect(old.minPrice, isNull);
    expect(old.brands, isEmpty);
    expect(old.sort, NearbySort.newest);

    final broken = NearbyFilter.fromJson({
      'kind': null,
      'cities': 'Казань',
      'when': 'yesterday',
      'min_price': '100',
      'brands': [1, 'Kia'],
      'sort': 42,
    });
    expect(broken.kind, isNull);
    expect(broken.cities, isEmpty);
    expect(broken.when, NearbyWhen.any);
    expect(broken.minPrice, isNull);
    expect(broken.brands, {'Kia'});
    expect(broken.sort, NearbySort.newest);
  });

  test('параметры запроса: пустой фильтр — без параметров', () {
    expect(const NearbyFilter().toQuery(), '');
    expect(
      const NearbyFilter(
        kind: OrderKind.inspection,
        cities: {'Химки', 'Москва'},
        when: NearbyWhen.today,
        minPrice: 5000,
        brands: {'Kia'},
        sort: NearbySort.priceDesc,
      ).toQuery(fewResponses: true),
      'kind=inspection'
      '&cities[]=%D0%9C%D0%BE%D1%81%D0%BA%D0%B2%D0%B0'
      '&cities[]=%D0%A5%D0%B8%D0%BC%D0%BA%D0%B8'
      '&brands[]=Kia&when=today&min_price=5000&few_responses=1'
      '&sort=price_desc',
    );
  });

  group('«Ближе ко мне» (бэклог №29)', () {
    const center = (55.751, 37.618);
    const nearest = NearbyFilter(sort: NearbySort.nearest);

    test('точка уходит на сервер только с этой сортировкой', () {
      expect(
        nearest.copyWith(near: () => (55.75123, 37.61789)).toQuery(),
        'sort=nearest&lat=55.751&lon=37.618',
      );
      // точки ещё нет — без координат, сервер отдаст «новые»
      expect(nearest.toQuery(), 'sort=nearest');
      expect(
        const NearbyFilter(sort: NearbySort.priceDesc, near: center).toQuery(),
        'sort=price_desc',
      );
    });

    test('сортировка сохраняется, точка — нет', () {
      final json = nearest.copyWith(near: () => center).toJson();
      expect(json.containsKey('near'), isFalse);
      final restored = NearbyFilter.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(restored.sort, NearbySort.nearest);
      expect(restored.near, isNull);
    });

    test('мок: ближе — раньше, без точки и подбор — в конец', () {
      final points = [
        selection(1),
        inspection(2, lat: 55.4312, lon: 37.5458), // Подольск
        inspection(3, lat: 55.7558, lon: 37.6173), // центр
        inspection(4), // без точки
        inspection(5, lat: 55.8897, lon: 37.4449), // Химки
      ];
      List<int> sorted(NearbyFilter f) =>
          applyNearbyFilter(points, f, now: now).map((o) => o.id).toList();

      expect(sorted(nearest.copyWith(near: () => center)), [3, 5, 2, 1, 4]);
      // без точки — порядок сервера («новые»)
      expect(sorted(nearest), [1, 2, 3, 4, 5]);
    });
  });
}
