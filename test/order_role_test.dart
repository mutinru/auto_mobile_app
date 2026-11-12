import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_action.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

import 'support/stores.dart';

/// Роль на экране заказа — из заказа (`viewer_role`, ревью №31), а кнопки —
/// по карте действий сервера (ревью №32), а не по вкладке и статусу.
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');
  const executor = UserSummary(id: 10, name: 'Игорь В.');

  /// Мок, который отдаёт заказ как есть — с ролью и картой «сервера».
  MockOrderRepository serverAnswers(Order order) => _AsIs(order);

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: screen));
    await tester.pumpAndSettle();
  }

  OrderStore store(Order order) => mockStore(
    orders: serverAnswers(order),
  );

  testWidgets('открыли «как исполнитель», а заказ — свой: действия заказчика', (
    tester,
  ) async {
    const order = Order(
      id: 501,
      status: OrderStatus.awaitingExecutor,
      brand: 'Kia',
      model: 'Rio',
      yearFrom: 2019,
      customer: customer,
      viewerRole: ViewerRole.customer,
      actions: {OrderAction.cancel},
    );

    await pump(
      tester,
      OrderDetailScreen(
        store: store(order),
        orderId: order.id,
        viewerIsCustomer: false,
      ),
    );

    expect(find.text('Отменить заказ'), findsOneWidget);
  });

  testWidgets('кнопка — только по ключу карты, не по статусу', (tester) async {
    const order = Order(
      id: 502,
      kind: OrderKind.inspection,
      status: OrderStatus.reportReady,
      brand: 'Kia',
      model: 'Rio',
      yearFrom: 2019,
      customer: customer,
      executor: executor,
      price: 3500,
      viewerRole: ViewerRole.customer,
    );

    await pump(
      tester,
      InspectionOrderDetailScreen(
        store: store(order),
        orderId: order.id,
        viewerIsCustomer: true,
      ),
    );
    expect(find.text('Я оплатил'), findsNothing, reason: 'сервер не разрешил');

    await pump(
      tester,
      // новый экран, а не тот же State с прежним заказом
      InspectionOrderDetailScreen(
        key: const ValueKey('разрешено'),
        store: store(order.copyWith(actions: {OrderAction.markPaid})),
        orderId: order.id,
        viewerIsCustomer: true,
      ),
    );
    expect(find.text('Я оплатил'), findsOneWidget);
  });
}

/// Отдаёт заказ без пересчёта карты: как ответил «сервер», так и есть.
class _AsIs extends MockOrderRepository {
  _AsIs(this.order) : super(orders: [order]);

  final Order order;

  @override
  Future<Order> fetchOrder(int id) async => order;
}
