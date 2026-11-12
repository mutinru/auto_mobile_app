import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_action.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_response.dart';
import 'package:auto_podbor_mobile/models/order_response_status.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

import 'support/stores.dart';

/// «Отменить заказ» (POST /orders/{id}/cancel): кнопка — по can_cancel с
/// сервера, правило отмены клиент не повторяет.
void main() {
  // id 1 — «я» в MockOrderRepository
  const customer = UserSummary(id: 1, name: 'Андрей С.');
  const executor = UserSummary(id: 10, name: 'Максим К.');

  Order order({
    OrderKind kind = OrderKind.selection,
    OrderStatus status = OrderStatus.awaitingExecutor,
    UserSummary? assigned,
  }) => Order(
    id: 4001,
    kind: kind,
    status: status,
    brand: 'Toyota',
    model: 'Camry',
    yearFrom: 2018,
    customer: customer,
    executor: assigned,
    responses: const [
      OrderResponse(
        id: 31,
        status: OrderResponseStatus.pending,
        proposedPrice: 10000,
        executor: executor,
      ),
    ],
  );

  Future<OrderStore> pump(
    WidgetTester tester,
    Order o, {
    bool viewerIsCustomer = true,
  }) async {
    final store = mockStore(
      orders: MockOrderRepository(orders: [o]),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: o.isInspection
            ? InspectionOrderDetailScreen(
                store: store,
                orderId: o.id,
                viewerIsCustomer: viewerIsCustomer,
              )
            : OrderDetailScreen(
                store: store,
                orderId: o.id,
                viewerIsCustomer: viewerIsCustomer,
              ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> confirmCancel(WidgetTester tester) async {
    await tester.tap(find.text('Отменить заказ'));
    await tester.pumpAndSettle();
    expect(find.text('Отменить заказ?'), findsOneWidget);
    // кнопка листа — последняя: под листом остаётся кнопка экрана
    await tester.tap(find.text('Отменить заказ').last);
    await tester.pumpAndSettle();
  }

  test('actions и viewer_role: без ключа — нельзя, незнакомое — мимо', () {
    Map<String, dynamic> json(Object? actions, [Object? role]) => {
      'id': 1,
      'status': 'awaiting_executor',
      'brand': 'Kia',
      'model': 'Rio',
      'customer': {'id': 1, 'name': 'А'},
      'actions': ?actions,
      'viewer_role': ?role,
    };
    expect(Order.fromJson(json(null)).canCancel, isFalse);
    expect(Order.fromJson(json(null)).actions, isEmpty);
    expect(Order.fromJson(json(null)).viewerRole, isNull);

    final order = Order.fromJson(
      json({
        'cancel': true,
        'repost': false,
        'from_the_future': true,
      }, 'customer'),
    );
    expect(order.canCancel, isTrue);
    expect(order.actions, {OrderAction.cancel});
    expect(order.viewerRole, ViewerRole.customer);
    expect(
      Order.fromJson(json([], 'executor')).viewerRole,
      ViewerRole.executor,
    );
  });

  testWidgets('подбор до выбора исполнителя отменяется', (tester) async {
    final store = await pump(tester, order());

    await confirmCancel(tester);

    expect(find.text('Отменить заказ'), findsNothing);
    final updated = await store.fetchOrder(4001);
    expect(updated.status, OrderStatus.cancelled);
    expect(updated.responses.single.status, OrderResponseStatus.rejected);
  });

  testWidgets('разовый осмотр до выбора исполнителя отменяется', (
    tester,
  ) async {
    final store = await pump(tester, order(kind: OrderKind.inspection));

    await confirmCancel(tester);

    expect(find.text('Отменить заказ'), findsNothing);
    expect((await store.fetchOrder(4001)).status, OrderStatus.cancelled);
  });

  testWidgets('«Не отменять» ничего не меняет', (tester) async {
    final store = await pump(tester, order());

    await tester.tap(find.text('Отменить заказ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Не отменять'));
    await tester.pumpAndSettle();

    expect((await store.fetchOrder(4001)).status, OrderStatus.awaitingExecutor);
    expect(find.text('Отменить заказ'), findsOneWidget);
  });

  testWidgets('после выбора исполнителя кнопки нет', (tester) async {
    await pump(tester, order(status: OrderStatus.sourcing, assigned: executor));
    expect(find.text('Отменить заказ'), findsNothing);
  });

  testWidgets('исполнитель кнопку не видит', (tester) async {
    await pump(tester, order(), viewerIsCustomer: false);
    expect(find.text('Отменить заказ'), findsNothing);
  });
}
