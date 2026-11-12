import 'dart:async';

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
import 'package:auto_podbor_mobile/state/paged_orders.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/order_card.dart';

const _customer = UserSummary(id: 1, name: 'Андрей С.');

Order _order(int id, OrderStatus status, {DateTime? closed}) => Order(
  id: id,
  kind: OrderKind.selection,
  status: status,
  brand: 'Kia',
  model: 'Rio $id',
  customer: _customer,
  cities: const ['Москва'],
  completedAt: status == OrderStatus.completed ? closed : null,
  selectionClosedAt: status == OrderStatus.closed ? closed : null,
);

/// Сервер: завершённые страницами по [size], номер запрошенных страниц —
/// в [requested].
class _Paged extends MockOrderRepository {
  _Paged(this.finished);

  static const size = 2;
  final List<Order> finished;
  final requested = <int>[];

  @override
  Future<List<Order>> fetchMyOrders() async => [
    _order(100, OrderStatus.sourcing),
  ];

  @override
  Future<OrderPage> fetchMyFinishedOrders({int page = 1}) async {
    requested.add(page);
    final start = (page - 1) * size;
    return OrderPage(
      items: finished.skip(start).take(size).toList(),
      hasMore: finished.length > start + size,
    );
  }
}

/// «Завершённые» страницами (ревью №9) и закрытый без покупки подбор.
void main() {
  final finished = [
    for (var i = 0; i < 5; i++)
      _order(
        10 + i,
        i == 0 ? OrderStatus.closed : OrderStatus.completed,
        closed: DateTime(2026, 11, 10 - i),
      ),
  ];

  test('closed разбирается: статус, время закрытия, «Завершённые»', () {
    final closed = Order.fromJson({
      'id': 1,
      'kind': 'selection',
      'status': 'closed',
      'brand': 'Kia',
      'model': 'Rio',
      'customer': {'id': 1, 'name': 'Андрей'},
      'closed_at': '2026-11-05T09:00:00.000000Z',
    });
    expect(closed.status, OrderStatus.closed);
    expect(closed.status.isFinished, isTrue);
    expect(closed.closedAt, DateTime.utc(2026, 11, 5, 9).toLocal());
    expect(closed.statusLabel, contains('закрыт без покупки'));
  });

  test(
    'страницы: подгрузка, дубли отброшены, устаревший ответ — тоже',
    () async {
      final repo = _Paged(finished);
      final paged = PagedOrders((p) => repo.fetchMyFinishedOrders(page: p));
      expect(paged.isLoaded, isFalse);

      await paged.load();
      expect(paged.items.map((o) => o.id), [10, 11]);
      expect(paged.hasMore, isTrue);

      await paged.loadMore();
      await paged.loadMore();
      expect(paged.items.map((o) => o.id), [10, 11, 12, 13, 14]);
      expect(paged.hasMore, isFalse);

      // вторая страница в пути, а первую перечитали — её ответ не подмешиваем
      final slow = Completer<OrderPage>();
      var call = 0;
      final racing = PagedOrders((p) {
        call++;
        return call == 2 ? slow.future : repo.fetchMyFinishedOrders(page: p);
      });
      await racing.load();
      final more = racing.loadMore();
      await racing.load();
      slow.complete(
        OrderPage(items: [_order(99, OrderStatus.completed)], hasMore: false),
      );
      await more;
      expect(racing.items.map((o) => o.id), isNot(contains(99)));
    },
  );

  testWidgets('вкладка грузит страницы при открытии и подвалом', (
    tester,
  ) async {
    final repo = _Paged(finished);
    final store = OrderStore(
      repo,
      catalog: MockCarCatalogRepository(),
      cities: MockCityRepository(),
    );
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
    // «Активные» завершённые не просят
    expect(repo.requested, isEmpty);

    await tester.tap(find.text('Завершённые'));
    await tester.pumpAndSettle();

    // высокий экран: подвал виден сразу и докачивает остальные страницы
    expect(repo.requested, [1, 2, 3]);
    expect(
      tester
          .widgetList<OrderCard>(find.byType(OrderCard))
          .map((c) => c.order.id),
      [10, 11, 12, 13, 14],
    );
    // пилюля статуса — заглавными
    expect(find.textContaining('ЗАКРЫТ БЕЗ ПОКУПКИ'), findsOneWidget);
  });

  testWidgets(
    'вкладка перечитывает первую страницу при каждом открытии (ревью №41)',
    (tester) async {
      // стор живёт сессию: заказ мог закрыться, пока вкладки не было видно
      final repo = _Paged(finished);
      final store = OrderStore(
        repo,
        catalog: MockCarCatalogRepository(),
        cities: MockCityRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MyOrdersScreen(store: store),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Завершённые'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Активные'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Завершённые'));
      await tester.pumpAndSettle();

      expect(repo.requested.where((p) => p == 1), hasLength(2));
      expect(find.byType(OrderCard), findsWidgets);
    },
  );
}
