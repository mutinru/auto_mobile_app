import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_verdict.dart';
import 'package:auto_podbor_mobile/models/notification_type.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';

/// Подпись подбора: «на осмотре» — только пока осмотр идёт.
void main() {
  OrderCar car(int id, String? inspection) => OrderCar(
    id: id,
    brand: 'Toyota',
    model: 'Camry',
    year: 2019,
    vinMasked: 'XW8••••1234',
    inspectionId: inspection == null ? null : id,
    inspectionStatus: inspection,
  );

  Order order(
    OrderStatus status,
    List<OrderCar> cars, {
    OrderKind kind = OrderKind.selection,
  }) => Order(
    id: 1,
    kind: kind,
    status: status,
    brand: 'Toyota',
    model: 'Camry',
    customer: const UserSummary(id: 1, name: 'Андрей С.'),
    cars: cars,
  );

  test('осмотр идёт — «на осмотре»', () {
    final o = order(OrderStatus.inspecting, [
      car(1, 'completed'),
      car(2, 'in_progress'),
    ]);
    expect(o.statusLabel, 'на осмотре');
    expect(o.shownStatus, OrderStatus.inspecting);
  });

  test('между осмотрами — «идёт подбор · осмотрено N»', () {
    final o = order(OrderStatus.inspecting, [
      car(1, 'completed'),
      car(2, 'completed'),
    ]);
    expect(o.statusLabel, 'идёт подбор · осмотрено 2');
    expect(o.shownStatus, OrderStatus.sourcing);
  });

  test('добавленный, но не осмотренный кандидат не считается', () {
    final o = order(OrderStatus.inspecting, [
      car(1, 'completed'),
      car(2, null),
    ]);
    expect(o.statusLabel, 'идёт подбор · осмотрено 1');
  });

  test('ещё ничего не смотрели — «идёт подбор»', () {
    expect(order(OrderStatus.sourcing, []).statusLabel, 'идёт подбор');
  });

  test('машины не пришли в ответе — статус как есть', () {
    expect(order(OrderStatus.inspecting, []).statusLabel, 'на осмотре');
  });

  test('разовый осмотр и прочие статусы не трогаем', () {
    final inspection = order(OrderStatus.inspecting, [
      car(1, 'completed'),
    ], kind: OrderKind.inspection);
    expect(inspection.statusLabel, 'на осмотре');
    expect(
      order(OrderStatus.completed, [car(1, 'completed')]).statusLabel,
      'выполнен',
    );
  });

  group('завершение осмотра кандидата', () {
    test(
      'мок: осмотр завершён вердиктом, заказ в поиске — «осмотрено 1»',
      () async {
        final started = order(OrderStatus.inspecting, [car(7, 'in_progress')]);
        expect(started.statusLabel, 'на осмотре');
        final repo = _OneOrderRepository(started);

        final done = await repo.completeCandidate(
          1,
          7,
          verdict: InspectionVerdict.recommended,
        );
        expect(done.status, OrderStatus.inspecting);
        expect(done.cars.single.inspectionStatus, 'completed');
        expect(done.statusLabel, 'идёт подбор · осмотрено 1');
        expect(done.cars.single.inspectionLabel, 'можно брать');
      },
    );

    test('уведомление candidate_inspected разбирается', () {
      expect(
        notificationTypeFromApi('candidate_inspected'),
        NotificationType.candidateInspected,
      );
      expect(
        NotificationType.candidateInspected.defaultViewerIsCustomer,
        isTrue,
      );
      expect(NotificationType.candidateInspected.opensOrder, isTrue);
    });
  });
}

/// Мок с одним заказом — чтобы не трогать общие сиды `MockOrderRepository`.
class _OneOrderRepository extends MockOrderRepository {
  _OneOrderRepository(this.order);

  final Order order;

  @override
  Future<Order> fetchOrder(int orderId) async => order;
}
