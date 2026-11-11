import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_verdict.dart';
import 'package:auto_podbor_mobile/models/notification_type.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/selection_close_reason.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/order_status_card.dart';

/// Выход из подбора (бекенд, ревью №2/№3): отказ исполнителя по
/// can_release, автоархив (closes_at), причина закрытия, новые уведомления.
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');
  const executor = UserSummary(id: 10, name: 'Игорь В.');
  const done = OrderCar(
    id: 81,
    brand: 'Kia',
    model: 'Rio',
    year: 2019,
    vinMasked: '··· 111111',
    inspectionId: 601,
    inspectionStatus: 'completed',
    verdict: InspectionVerdict.recommended,
  );
  const started = OrderCar(
    id: 83,
    brand: 'VW',
    model: 'Polo',
    year: 2018,
    vinMasked: '··· 333333',
    inspectionId: 603,
    inspectionStatus: 'in_progress',
  );

  Order selection({
    OrderStatus status = OrderStatus.inspecting,
    SelectionCloseReason? reason,
    DateTime? closesAt,
  }) => Order(
    id: 3201,
    status: status,
    brand: 'Kia',
    model: 'Rio',
    customer: customer,
    executor: executor,
    cars: const [done, started],
    closeReason: reason,
    closesAt: closesAt,
  );

  test('разбор: can_release, close_reason, closes_at, новые уведомления', () {
    final order = Order.fromJson({
      'id': 1,
      'kind': 'selection',
      'status': 'closed',
      'brand': 'Kia',
      'model': 'Rio',
      'customer': {'id': 1, 'name': 'Андрей'},
      'can_release': true,
      'close_reason': 'account_deleted',
      'closes_at': '2026-12-20T09:00:00.000000Z',
    });
    expect(order.canRelease, isTrue);
    expect(order.closeReason, SelectionCloseReason.accountDeleted);
    expect(order.closesAt, DateTime.utc(2026, 12, 20, 9).toLocal());
    expect(selectionCloseReasonFromApi('новая'), SelectionCloseReason.unknown);
    expect(selectionCloseReasonFromApi(null), isNull);

    expect(
      notificationTypeFromApi('selection_close_soon'),
      NotificationType.selectionCloseSoon,
    );
    final closed = notificationTypeFromApi('selection_closed');
    expect(closed, NotificationType.selectionClosed);
    expect(closed.opensOrder, isTrue);
  });

  testWidgets('подпись: причина закрытия и «закроется …»', (tester) async {
    Future<void> card(Order order) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: OrderStatusCard(order: order)),
      ),
    );

    await card(
      selection(
        status: OrderStatus.closed,
        reason: SelectionCloseReason.inactive,
      ).copyWith(cars: const [done]),
    );
    expect(find.text('Закрыт без покупки'), findsOneWidget);
    expect(find.text('Два месяца не было новостей'), findsOneWidget);

    await card(
      selection(
        status: OrderStatus.sourcing,
        closesAt: DateTime(2026, 12, 20),
      ).copyWith(cars: const [done]),
    );
    expect(
      find.text('Закроется 20 декабря, если не будет новостей'),
      findsOneWidget,
    );
  });

  testWidgets(
    'исполнитель отказывается от подбора — заказ в ленте, экран закрыт',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final repo = MockOrderRepository(orders: [selection()]);
      final store = OrderStore(
        repo,
        catalog: MockCarCatalogRepository(),
        cities: MockCityRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(
                    store: store,
                    orderId: 3201,
                    viewerIsCustomer: false,
                  ),
                ),
              ),
              child: const Text('открыть'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Отказаться от подбора'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Отказаться от подбора'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отказаться'));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailScreen), findsNothing);
      final order = await repo.fetchOrder(3201);
      expect(order.status, OrderStatus.awaitingExecutor);
      expect(order.executor, isNull);
      // готовый отчёт остался, начатый осмотр — нет
      expect(order.cars.map((c) => c.id), [81]);
    },
  );

  testWidgets('без can_release кнопки нет', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // закрытый подбор: мок, как сервер, отказ не разрешает
    final repo = MockOrderRepository(
      orders: [selection(status: OrderStatus.closed)],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OrderDetailScreen(
          store: OrderStore(
            repo,
            catalog: MockCarCatalogRepository(),
            cities: MockCityRepository(),
          ),
          orderId: 3201,
          viewerIsCustomer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Отказаться от подбора'), findsNothing);
  });
}
