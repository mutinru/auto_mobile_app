import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/notification_type.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_response.dart';
import 'package:auto_podbor_mobile/models/order_response_status.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/time_slot.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/executor_stats.dart';
import 'package:auto_podbor_mobile/widgets/inspection_when_picker.dart';

/// Срок осмотра — день осмотра: срыв или пропущенный день → заказчик
/// решает, разместить заново или отменить; срывы видит только заказчик.
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');
  const sergey = UserSummary(
    id: 7,
    name: 'Сергей П.',
    completedOrdersCount: 12,
    missedOrdersCount: 1,
  );

  Order decisionOrder({DecisionReason reason = DecisionReason.missed}) => Order(
    id: 501,
    kind: OrderKind.inspection,
    status: OrderStatus.awaitingDecision,
    brand: 'Kia',
    model: 'Rio',
    yearFrom: 2019,
    customer: customer,
    cities: const ['Химки'],
    address: 'ул. Ленина, 5',
    inspectOn: DateTime(2026, 11, 3),
    timeSlot: TimeSlot.day,
    askingPrice: 3500,
    canCancel: true,
    decisionReason: reason,
    responses: const [
      OrderResponse(
        id: 9,
        status: OrderResponseStatus.pending,
        proposedPrice: 3000,
        executor: sergey,
      ),
    ],
  );

  test('статус и типы уведомлений с сервера', () {
    expect(
      orderStatusFromApi('awaiting_decision'),
      OrderStatus.awaitingDecision,
    );
    expect(OrderStatus.awaitingDecision.label, 'ждёт решения');
    expect(OrderStatus.awaitingDecision.isFinished, isFalse);

    expect(
      notificationTypeFromApi('deadline_missed'),
      NotificationType.deadlineMissed,
    );
    expect(
      notificationTypeFromApi('inspection_date_passed'),
      NotificationType.inspectionDatePassed,
    );
    expect(
      notificationTypeFromApi('order_rescheduled'),
      NotificationType.orderRescheduled,
    );
    // сорвавший заказ уже не видит — тап только читает уведомление
    expect(NotificationType.deadlineMissed.opensOrder, isFalse);
    expect(NotificationType.orderRescheduled.opensOrder, isTrue);
    expect(NotificationType.deadlineMissed.defaultViewerIsCustomer, isFalse);
  });

  test('срывы в сводке — только когда сервер их отдал (заказчику)', () {
    expect(
      ExecutorStats.summary(sergey),
      'Новый исполнитель · 12 заказов · 1 срыв',
    );
    expect(
      ExecutorStats.summary(
        const UserSummary(
          id: 2,
          name: 'Олег',
          completedOrdersCount: 3,
          missedOrdersCount: 0,
        ),
      ),
      'Новый исполнитель · 3 заказа · 0 срывов',
    );
    expect(
      ExecutorStats.summary(
        const UserSummary(id: 2, name: 'Олег', completedOrdersCount: 3),
      ),
      'Новый исполнитель · 3 заказа',
    );
    expect(
      UserSummary.fromJson(const {'id': 2, 'name': 'Олег'}).missedOrdersCount,
      isNull,
    );
  });

  testWidgets('после 21:00 «Сегодня» не предлагаем', (tester) async {
    Future<void> pump(DateTime now) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: InspectionWhenPicker(
              value: InspectionWhen(
                date: firstInspectionDay(now),
                slot: TimeSlot.day,
              ),
              now: () => now,
              onChanged: (_) {},
            ),
          ),
        ),
      );
    }

    // подписи «Сегодня»/«Завтра» считаются от настоящей даты — берём её
    final today = DateTime.now();
    await pump(DateTime(today.year, today.month, today.day, 20, 59));
    expect(find.text('Сегодня'), findsOneWidget);

    await pump(DateTime(today.year, today.month, today.day, 21));
    expect(find.text('Сегодня'), findsNothing);
    expect(find.text('Завтра'), findsOneWidget);
    expect(
      firstInspectionDay(DateTime(2026, 11, 2, 21)),
      DateTime(2026, 11, 3),
    );
  });

  testWidgets(
    'срыв: причина, «Разместить заново» с новой датой, старые отклики скрыты',
    (tester) async {
      final repo = MockOrderRepository(orders: [decisionOrder()]);
      final store = OrderStore(
        repo,
        catalog: MockCarCatalogRepository(),
        cities: MockCityRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: InspectionOrderDetailScreen(store: store, orderId: 501),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('НУЖНО РЕШЕНИЕ'), findsOneWidget);
      expect(find.textContaining('не провёл осмотр'), findsOneWidget);
      // выбрать из старых откликов нельзя; отменить — кнопка внизу списка
      expect(find.text('Сергей П.'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Отменить заказ'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Разместить заново'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text('Разместить заново'));
      await tester.pumpAndSettle();
      expect(find.text('Ваша цена'.toUpperCase()), findsOneWidget);
      await tester.tap(find.text('Разместить'));
      await tester.pumpAndSettle();

      final updated = await repo.fetchOrder(501);
      expect(updated.status, OrderStatus.awaitingExecutor);
      expect(updated.decisionReason, isNull);
      expect(updated.responses.single.status, OrderResponseStatus.rejected);
      expect(find.text('НУЖНО РЕШЕНИЕ'), findsNothing);
    },
  );

  testWidgets('день прошёл без исполнителя — своя причина', (tester) async {
    final store = OrderStore(
      MockOrderRepository(
        orders: [decisionOrder(reason: DecisionReason.datePassed)],
      ),
      catalog: MockCarCatalogRepository(),
      cities: MockCityRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionOrderDetailScreen(store: store, orderId: 501),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('исполнитель так и не выбран'), findsOneWidget);
  });
}
