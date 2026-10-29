import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_outcome.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// «Зафиксировать покупку» закрывает подбор (POST /orders/{id}/complete).
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');
  const executor = UserSummary(id: 10, name: 'Максим К.');

  // свой набор: кандидаты в общей фикстуре сдвинули бы соседние suites
  Order selection({OrderStatus status = OrderStatus.inspecting, List<OrderCar>? cars}) => Order(
        id: 3001,
        status: status,
        brand: 'Toyota',
        model: 'Camry',
        yearFrom: 2018,
        customer: customer,
        executor: executor,
        price: 12000,
        cars: cars ??
            const [
              OrderCar(
                id: 71,
                brand: 'Toyota',
                model: 'Camry',
                year: 2019,
                vinMasked: '··· 123456',
                mileageKm: 58000,
                inspectionId: 501,
                inspectionStatus: 'completed',
              ),
              OrderCar(
                id: 72,
                brand: 'Toyota',
                model: 'Camry',
                year: 2020,
                vinMasked: '··· 654321',
                mileageKm: 41000,
                inspectionId: 502,
                inspectionStatus: 'completed',
              ),
            ],
      );

  Future<OrderStore> pump(
    WidgetTester tester,
    Order order, {
    bool viewerIsCustomer = true,
  }) async {
    final store = OrderStore(
      MockOrderRepository(orders: [order]),
      catalog: MockCarCatalogRepository(),
      cities: MockCityRepository(),
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: OrderDetailScreen(
        store: store,
        orderId: order.id,
        viewerIsCustomer: viewerIsCustomer,
      ),
    ));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('выбор кандидата закрывает подбор и предлагает отзыв', (tester) async {
    final store = await pump(tester, selection());

    await tester.tap(find.text('Зафиксировать покупку'));
    await tester.pumpAndSettle();
    expect(find.text('Какую машину купили?'), findsOneWidget);

    // пока машина не выбрана, подтвердить нельзя: кнопка листа — вторая
    final confirm = find.widgetWithText(ElevatedButton, 'Зафиксировать покупку').last;
    expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);

    await tester.tap(find.text('VIN ··· 654321'));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Какую машину купили?'), findsNothing);
    expect(find.text('Зафиксировать покупку'), findsNothing);
    expect(find.text('Оставить отзыв'), findsOneWidget);
    // исход — по-русски, а не сырое purchased/rejected
    expect(find.text('куплена'), findsOneWidget);
    expect(find.text('не подошла'), findsOneWidget);

    final updated = await store.fetchOrder(3001);
    expect(updated.status, OrderStatus.completed);
    expect(updated.cars.map((c) => c.inspectionOutcome),
        [InspectionOutcome.rejected, InspectionOutcome.purchased]);
  });

  test('подпись кандидата: исход, затем статус осмотра', () {
    OrderCar car(Map<String, dynamic>? inspection) => OrderCar.fromJson({
          'id': 1,
          'brand': 'Kia',
          'model': 'Rio',
          'year': 2019,
          'vin_masked': '—',
          'mileage_km': 1,
          'inspection': inspection,
        });

    expect(car(null).inspectionLabel, 'осмотр не начат');
    expect(car({'id': 5, 'status': 'in_progress'}).inspectionLabel, 'идёт осмотр');
    expect(car({'id': 5, 'status': 'completed'}).inspectionLabel, 'осмотрена');
    expect(car({'id': 5, 'status': 'completed', 'outcome': 'purchased'}).inspectionLabel, 'куплена');
    expect(car({'id': 5, 'status': 'completed', 'outcome': 'rejected'}).inspectionLabel, 'не подошла');
    // незнакомое значение не попадает на экран как есть
    final unknown = car({'id': 5, 'status': 'archived', 'outcome': 'returned'});
    expect(unknown.inspectionOutcome, isNull);
    expect(unknown.inspectionLabel, 'осмотр');
  });

  testWidgets('суммы и пробег с разрядами, бюджет без «0» и «?»', (tester) async {
    final order = Order(
      id: 3002,
      status: OrderStatus.awaitingExecutor,
      brand: 'Kia',
      model: 'Sportage',
      yearFrom: 2021,
      mileageTo: 120000,
      budgetMin: 2000000,
      budgetMax: 2400000,
      customer: customer,
      executor: executor,
      price: 12000,
    );
    await pump(tester, order);
    expect(find.textContaining('пробег до 120 000 км'), findsOneWidget);
    expect(find.textContaining('2 000 000 — 2 400 000 ₽'), findsOneWidget);
    expect(find.text('12 000 ₽'), findsOneWidget);
  });

  testWidgets('бюджет только сверху — «до …»', (tester) async {
    await pump(
      tester,
      const Order(
        id: 3003,
        status: OrderStatus.awaitingExecutor,
        brand: 'Kia',
        model: 'Rio',
        budgetMax: 3100000,
        customer: customer,
      ),
    );
    expect(find.text('до 3 100 000 ₽'), findsOneWidget);
    expect(find.textContaining('0 —'), findsNothing);
  });

  testWidgets('без кандидатов кнопки нет', (tester) async {
    await pump(tester, selection(status: OrderStatus.sourcing, cars: const []));
    expect(find.text('Зафиксировать покупку'), findsNothing);
  });

  testWidgets('исполнитель кнопку не видит', (tester) async {
    await pump(tester, selection(), viewerIsCustomer: false);
    expect(find.text('Зафиксировать покупку'), findsNothing);
  });

  testWidgets('завершённый подбор кнопку не показывает', (tester) async {
    await pump(tester, selection(status: OrderStatus.completed));
    expect(find.text('Зафиксировать покупку'), findsNothing);
  });
}
