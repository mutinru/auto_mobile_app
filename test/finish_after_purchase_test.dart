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
import 'package:auto_podbor_mobile/screens/my_orders_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Подбор закрыт покупкой, а осмотр другого кандидата ещё идёт: исполнитель
/// его дозавершает — заказ остаётся у него в «Активных».
void main() {
  const customer = UserSummary(id: 2, name: 'Ольга К.');
  const executor = UserSummary(id: 1, name: 'Андрей С.');

  Order closed({String otherStatus = 'in_progress'}) => Order(
    id: 3201,
    status: OrderStatus.completed,
    brand: 'Kia',
    model: 'Rio',
    yearFrom: 2018,
    customer: customer,
    executor: executor,
    price: 12000,
    cars: [
      const OrderCar(
        id: 91,
        brand: 'Kia',
        model: 'Rio',
        year: 2019,
        vinMasked: '··· 111111',
        inspectionId: 701,
        inspectionStatus: 'completed',
        inspectionOutcome: InspectionOutcome.purchased,
      ),
      OrderCar(
        id: 92,
        brand: 'Kia',
        model: 'Rio',
        year: 2020,
        vinMasked: '··· 222222',
        inspectionId: 702,
        inspectionStatus: otherStatus,
        inspectionOutcome: InspectionOutcome.rejected,
      ),
    ],
  );

  test('закрытый подбор с идущим осмотром — «осмотр не завершён»', () {
    expect(closed().hasUnfinishedInspection, isTrue);
    expect(closed().statusLabel, 'выполнен · осмотр не завершён');
    final done = closed(otherStatus: 'completed');
    expect(done.hasUnfinishedInspection, isFalse);
    expect(done.statusLabel, 'выполнен');
    // идущий осмотр важнее исхода «не подошла» — его ещё доделывают
    expect(closed().cars.last.inspectionLabel, 'идёт осмотр');
    expect(done.cars.last.inspectionLabel, 'не подошла');
  });

  Future<void> pumpTaken(WidgetTester tester, Order order) async {
    final store = OrderStore(
      MockOrderRepository(orders: [order]),
      catalog: MockCarCatalogRepository(),
      cities: MockCityRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MyOrdersScreen(store: store, asExecutor: true),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('у исполнителя такой заказ — в «Активных»', (tester) async {
    await pumpTaken(tester, closed());
    expect(find.text('Kia Rio 2018+'), findsOneWidget);
  });

  testWidgets('всё осмотрено — заказ уходит в «Завершённые»', (tester) async {
    await pumpTaken(tester, closed(otherStatus: 'completed'));
    expect(find.text('Kia Rio 2018+'), findsNothing);
    await tester.tap(find.text('Завершённые'));
    await tester.pumpAndSettle();
    expect(find.text('Kia Rio 2018+'), findsOneWidget);
  });
}
