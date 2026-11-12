import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/mock_fixtures.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_verdict.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/state/order_detail_controller.dart';

import 'support/stores.dart';

/// Подбор Андрея с осмотренным кандидатом — покупку можно отметить.
Order _selection() => const Order(
  id: 7,
  status: OrderStatus.sourcing,
  brand: 'Kia',
  model: 'Rio',
  customer: MockFixtures.me,
  executor: MockFixtures.maxim,
  cars: [
    OrderCar(
      id: 1,
      brand: 'Kia',
      model: 'Rio',
      year: 2019,
      vinMasked: '··· 100111',
      inspectionId: 5,
      inspectionStatus: 'completed',
      verdict: InspectionVerdict.recommended,
    ),
  ],
);

/// Покупка ждёт команды теста — чтобы нажать второй раз, пока первая идёт.
class _SlowPurchase extends MockOrderRepository {
  _SlowPurchase() : super(orders: [_selection()]);

  final gate = Completer<void>();
  int purchases = 0;

  @override
  Future<Order> completeSelection(int orderId, {required int carId}) async {
    purchases++;
    await gate.future;
    return super.completeSelection(orderId, carId: carId);
  }
}

/// Сервер отказывает в перевыборе покупки (422).
class _Refusing extends MockOrderRepository {
  _Refusing() : super(orders: [_selection()]);

  @override
  Future<Order> changePurchase(int orderId, {required int carId}) async =>
      throw ApiException(422, '{"message":"Окно перевыбора закрыто"}');
}

class _Broken extends MockOrderRepository {
  @override
  Future<Order> fetchOrder(int id) async =>
      throw ApiException(500, '{"message":"boom"}');
}

/// Контроллер экрана подбора (ревью №16) — без виджетов.
void main() {
  test('загрузка: заказ и роль из него', () async {
    final c = OrderDetailController(
      mockStore(orders: MockOrderRepository(orders: [_selection()])),
      orderId: 7,
      viewerIsCustomerHint: false,
    );
    expect(c.loading, isTrue);

    await c.load();

    expect(c.loading, isFalse);
    expect(c.error, isNull);
    expect(c.order?.id, 7);
    // роли в моке нет — до неё подсказка экрана
    expect(c.viewerIsCustomer, isFalse);
  });

  test('сбой загрузки — текст ошибки, без вечного спиннера', () async {
    final c = OrderDetailController(
      mockStore(orders: _Broken()),
      orderId: 7,
      viewerIsCustomerHint: true,
    );

    await c.load();

    expect(c.loading, isFalse);
    expect(c.order, isNull);
    expect(c.error, isNotNull);
  });

  test('покупка подменяет заказ и в списках стора', () async {
    final store = mockStore(
      orders: MockOrderRepository(orders: [_selection()]),
    );
    await store.loadMyOrders();
    final c = OrderDetailController(
      store,
      orderId: 7,
      viewerIsCustomerHint: true,
    );
    await c.load();
    expect(c.canCompletePurchase(c.order!), isTrue);

    await c.completePurchase(1);

    expect(c.order?.status, OrderStatus.completed);
    expect(c.completing, isFalse);
    expect(
      store.myOrders.firstWhere((o) => o.id == 7).status,
      OrderStatus.completed,
    );
  });

  test('повтор, пока действие идёт, — один запрос; опрос на паузе', () async {
    final repo = _SlowPurchase();
    final c = OrderDetailController(
      mockStore(orders: repo),
      orderId: 7,
      viewerIsCustomerHint: true,
    );
    await c.load();

    final first = c.completePurchase(1);
    await Future<void>.delayed(Duration.zero);
    expect(c.busy, isTrue);
    await c.completePurchase(1);
    repo.gate.complete();
    await first;

    expect(repo.purchases, 1);
    expect(c.busy, isFalse);
  });

  test('ошибка действия пробрасывается, флаг гаснет', () async {
    final c = OrderDetailController(
      mockStore(orders: _Refusing()),
      orderId: 7,
      viewerIsCustomerHint: true,
    );
    await c.load();

    await expectLater(c.changePurchase(1), throwsA(isA<ApiException>()));
    expect(c.purchaseBusy, isFalse);
  });
}
