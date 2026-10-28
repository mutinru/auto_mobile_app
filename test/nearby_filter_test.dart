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
    String? address,
    DateTime? on,
    int? price,
    String brand = 'Kia',
  }) => Order(
    id: id,
    kind: OrderKind.inspection,
    status: OrderStatus.awaitingExecutor,
    brand: brand,
    model: 'Rio',
    customer: customer,
    address: address,
    inspectOn: on,
    askingPrice: price,
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
      address: 'Химки, ул. Ленина, 5',
      on: DateTime(2026, 10, 22),
      price: 4000,
    ),
    inspection(
      3,
      address: 'Москва, Варшавское ш., 170',
      on: DateTime(2026, 10, 23),
      price: 3000,
      brand: 'BMW',
    ),
    inspection(
      4,
      address: 'Мытищи, ул. Мира, 12',
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

  test('город берётся из cities у подбора и из адреса у осмотра', () {
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
}
