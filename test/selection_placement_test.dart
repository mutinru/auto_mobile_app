import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/notification_type.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

import 'support/stores.dart';

/// Платное размещение подбора (бекенд: SELECTION_PLACEMENT_FEE): оплата до
/// публикации, срок выбора исполнителя, решение после отказа исполнителя.
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');

  Order selection(
    OrderStatus status, {
    DecisionReason? reason,
    DateTime? pickUntil,
  }) => Order(
    id: 3301,
    status: status,
    brand: 'Kia',
    model: 'Rio',
    customer: customer,
    placementFee: 490,
    decisionReason: reason,
    pickUntil: pickUntil,
  );

  Future<MockOrderRepository> open(WidgetTester tester, Order order) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = MockOrderRepository(orders: [order]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OrderDetailScreen(
          store: mockStore(orders: repo),
          orderId: order.id,
          viewerIsCustomer: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  test('разбор: pick_until, executor_released, pick_deadline_soon', () {
    final order = Order.fromJson({
      'id': 1,
      'kind': 'selection',
      'status': 'awaiting_decision',
      'brand': 'Kia',
      'model': 'Rio',
      'customer': {'id': 1, 'name': 'Андрей'},
      'decision_reason': 'executor_released',
      'pick_until': '2026-11-20T09:00:00.000000Z',
    });
    expect(order.decisionReason, DecisionReason.executorReleased);
    expect(order.pickUntil, DateTime.utc(2026, 11, 20, 9).toLocal());
    expect(
      notificationTypeFromApi('pick_deadline_soon'),
      NotificationType.pickDeadlineSoon,
    );
  });

  testWidgets('не оплачен — подсказка и «Оплатить размещение»', (
    tester,
  ) async {
    await open(tester, selection(OrderStatus.awaitingPlacement));

    expect(find.text('ОПЛАТА РАЗМЕЩЕНИЯ'), findsOneWidget);
    expect(find.text('Оплатить размещение · 490 ₽'), findsOneWidget);
    expect(
      find.textContaining('когда вы выберете исполнителя'),
      findsOneWidget,
    );
  });

  testWidgets('ждёт исполнителя — срок выбора с сервера', (tester) async {
    await open(
      tester,
      selection(
        OrderStatus.awaitingExecutor,
        pickUntil: DateTime(2026, 11, 20, 12),
      ),
    );

    expect(
      find.textContaining('Выберите исполнителя из откликов до'),
      findsOneWidget,
    );
    expect(find.textContaining('20 ноября'), findsOneWidget);
    expect(
      find.textContaining('деньги за размещение вернутся'),
      findsOneWidget,
    );
  });

  testWidgets('исполнитель отказался — «Разместить заново» без оплаты', (
    tester,
  ) async {
    final repo = await open(
      tester,
      selection(
        OrderStatus.awaitingDecision,
        reason: DecisionReason.executorReleased,
      ),
    );

    expect(find.text('НУЖНО РЕШЕНИЕ'), findsOneWidget);
    expect(find.textContaining('второй раз платить не нужно'), findsOneWidget);
    await tester.tap(find.text('Разместить заново'));
    await tester.pumpAndSettle();

    final order = await repo.fetchOrder(3301);
    expect(order.status, OrderStatus.awaitingExecutor);
    expect(order.decisionReason, isNull);
    expect(order.pickUntil, isNotNull);
    expect(find.text('Разместить заново'), findsNothing);
  });
}
