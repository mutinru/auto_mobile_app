import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/assigned_inspection_screen.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/util/route_link.dart';

import 'support/stores.dart';

/// «Маршрут до осмотра» (бэклог №28): по точке — только если она сам дом.
void main() {
  Order order({
    OrderStatus status = OrderStatus.scheduled,
    String? address = 'ул. Ленина, 5',
    double? lat = 55.889,
    double? lon = 37.445,
    int? precision = 0,
  }) => Order(
    id: 4001,
    kind: OrderKind.inspection,
    status: status,
    brand: 'Kia',
    model: 'Rio',
    customer: const UserSummary(id: 1, name: 'Андрей С.'),
    executor: const UserSummary(id: 10, name: 'Максим К.'),
    cities: const ['Химки'],
    address: address,
    lat: lat,
    lon: lon,
    addressPrecision: precision,
  );

  test('точный адрес — по координатам, запасной — Яндекс с маршрутом', () {
    for (final precision in [0, 1]) {
      final links = routeLinks(order(precision: precision));
      expect(links.first.scheme, 'geo');
      expect(links.first.path, '55.889,37.445');
      expect(
        links.first.queryParameters['q'],
        '55.889,37.445(Химки, ул. Ленина, 5)',
      );
      expect(links.last.host, 'yandex.ru');
      expect(links.last.queryParameters, {
        'rtext': '~55.889,37.445',
        'rtt': 'auto',
      });
    }
  });

  test('неточная точка или центр города — поиском по адресу', () {
    for (final precision in [2, 3, null]) {
      final links = routeLinks(order(precision: precision));
      expect(links.first.toString(), startsWith('geo:0,0?q='));
      expect(links.first.queryParameters['q'], 'Химки, ул. Ленина, 5');
      expect(links.last.queryParameters, {'text': 'Химки, ул. Ленина, 5'});
    }
  });

  test('ни адреса, ни точной точки — открывать нечего', () {
    expect(routeLinks(order(address: null, precision: null)), isEmpty);
    // точная точка без адреса — всё равно маршрут
    expect(routeLinks(order(address: null)).first.path, '55.889,37.445');
  });

  test('address_precision из JSON', () {
    final parsed = Order.fromJson({
      'id': 1,
      'kind': 'inspection',
      'status': 'scheduled',
      'brand': 'Kia',
      'model': 'Rio',
      'customer': {'id': 1, 'name': 'Андрей'},
      'lat': 55.889,
      'lon': 37.445,
      'address_precision': 1,
    });
    expect(parsed.addressPrecision, 1);
    expect(parsed.hasExactPoint, isTrue);
  });

  Future<void> show(
    WidgetTester tester,
    Widget Function(OrderStore) screen,
    Order o,
  ) async {
    final store = mockStore(
      orders: MockOrderRepository(orders: [o]),
    );
    // прошлый экран — прочь, иначе его состояние переживёт новый стор
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: screen(store)),
    );
    await tester.pumpAndSettle();
  }

  Widget executor(OrderStore store) =>
      AssignedInspectionScreen(store: store, orderId: 4001);

  testWidgets('кнопка — у исполнителя до и во время осмотра', (tester) async {
    await show(tester, executor, order());
    expect(find.text('Маршрут до осмотра'), findsOneWidget);

    await show(tester, executor, order(status: OrderStatus.inspecting));
    expect(find.text('Маршрут до осмотра'), findsOneWidget);
  });

  testWidgets('после осмотра и у заказчика кнопки нет', (tester) async {
    await show(tester, executor, order(status: OrderStatus.reportReady));
    expect(find.text('Маршрут до осмотра'), findsNothing);

    await show(
      tester,
      (store) => InspectionOrderDetailScreen(store: store, orderId: 4001),
      order(),
    );
    expect(find.text('Маршрут до осмотра'), findsNothing);
  });
}
