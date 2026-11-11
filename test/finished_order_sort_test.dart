import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_page.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/my_orders_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/order_card.dart';

class _Repo extends MockOrderRepository {
  _Repo(this.orders);

  final List<Order> orders;

  /// Как сервер: активные отдельно, завершённые — своей страницей (здесь в
  /// порядке фикстуры: сортирует экран).
  @override
  Future<List<Order>> fetchMyOrders() async =>
      orders.where((o) => !o.status.isFinished).toList();

  @override
  Future<OrderPage> fetchMyFinishedOrders({int page = 1}) async => OrderPage(
    items: orders.where((o) => o.status.isFinished).toList(),
    hasMore: false,
  );
}

/// «Завершённые» — от последнего закрытого (QA 2026-11-05 №7).
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');

  Order order(
    int id,
    String model,
    OrderStatus status, {
    DateTime? completed,
    DateTime? cancelled,
  }) => Order(
    id: id,
    kind: OrderKind.inspection,
    status: status,
    brand: 'Kia',
    model: model,
    yearFrom: 2018,
    customer: customer,
    cities: const ['Москва'],
    completedAt: completed,
    cancelledAt: cancelled,
  );

  test('cancelled_at разбирается, closedAt — завершение или отмена', () {
    final cancelled = Order.fromJson({
      'id': 1,
      'kind': 'selection',
      'status': 'cancelled',
      'brand': 'Kia',
      'model': 'Rio',
      'customer': {'id': 1, 'name': 'Андрей'},
      'completed_at': null,
      'cancelled_at': '2026-11-05T09:00:00.000000Z',
    });
    expect(cancelled.cancelledAt, DateTime.utc(2026, 11, 5, 9).toLocal());
    expect(cancelled.closedAt, cancelled.cancelledAt);
  });

  testWidgets('свежие сверху, без метки — внизу по номеру; активные как были', (
    tester,
  ) async {
    final orders = [
      // порядок сервера: осмотры по дате выезда, старые первыми
      order(
        12,
        'Old',
        OrderStatus.completed,
        completed: DateTime(2026, 10, 20),
      ),
      order(5, 'NoMark', OrderStatus.cancelled),
      order(
        21,
        'Cancelled',
        OrderStatus.cancelled,
        cancelled: DateTime(2026, 11, 5, 9),
      ),
      order(
        60,
        'Fresh',
        OrderStatus.completed,
        completed: DateTime(2026, 11, 5, 12),
      ),
      order(8, 'NoMark2', OrderStatus.cancelled),
      order(70, 'ActiveB', OrderStatus.awaitingExecutor),
      order(71, 'ActiveA', OrderStatus.awaitingExecutor),
    ];
    final store = OrderStore(
      _Repo(orders),
      catalog: MockCarCatalogRepository(),
      cities: MockCityRepository(),
    );
    // высокий экран: все карточки построены, порядок — по дереву
    tester.view.physicalSize = const Size(900, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MyOrdersScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    List<int> shown() => tester
        .widgetList<OrderCard>(find.byType(OrderCard))
        .map((c) => c.order.id)
        .toList();

    // активные — в порядке сервера
    expect(shown(), [70, 71]);

    await tester.tap(find.text('Завершённые'));
    await tester.pumpAndSettle();
    expect(shown(), [60, 21, 12, 8, 5]);
  });
}
