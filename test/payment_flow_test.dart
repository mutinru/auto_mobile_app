import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_verdict.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_response_status.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/report_summary.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/assigned_inspection_screen.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/deadline_countdown.dart';

/// Разовый осмотр после вердикта: оплата напрямую, подтверждение, спор,
/// отказ исполнителя (docs/plan-inspection-payment-flow.md на бекенде).
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');
  const executor = UserSummary(id: 10, name: 'Максим К.');

  Order inspection(OrderStatus status, {DateTime? deadline}) => Order(
        id: 3001,
        kind: OrderKind.inspection,
        status: status,
        brand: 'Hyundai',
        model: 'Solaris',
        yearFrom: 2018,
        customer: customer,
        executor: executor,
        price: 3500,
        askingPrice: 3500,
        address: 'Москва, Профсоюзная ул., 56',
        executorDeadlineAt: deadline,
        payout: status.isAwaitingPayment ? MockOrderRepository.mockPayout : null,
        reportSummary: status.isAwaitingPayment
            ? const ReportSummary(panelsTotal: 13, panelsInspected: 13, defectsCount: 2, photosCount: 5)
            : null,
        cars: const [
          OrderCar(
            id: 901,
            brand: 'Hyundai',
            model: 'Solaris',
            year: 2018,
            vinMasked: '—',
            mileageKm: 96000,
            inspectionId: 77,
            inspectionStatus: 'completed',
            verdict: InspectionVerdict.notRecommended,
            verdictComment: 'Подвеска под замену',
          ),
        ],
      );

  OrderStore store(MockOrderRepository repo) =>
      OrderStore(repo, catalog: MockCarCatalogRepository(), cities: MockCityRepository());

  /// Экран открыт поверх «домашнего», чтобы его закрытие было видно.
  Widget host(Widget Function() screen) => MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen())),
                child: const Text('открыть'),
              ),
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester, Widget Function() screen) async {
    await tester.pumpWidget(host(screen));
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();
  }

  group('модели', () {
    test('новые статусы, отклики, реквизиты, сводка и спор', () {
      final order = Order.fromJson({
        'id': 1,
        'kind': 'inspection',
        'status': 'report_ready',
        'brand': 'Kia',
        'model': 'Rio',
        'price': 3500,
        'customer': {'id': 1, 'name': 'Андрей'},
        'executor_deadline_at': '2026-10-29T10:00:00.000000Z',
        'payout': {'card': '2200700000000009', 'phone': null, 'bank': null},
        'report_summary': {'panels_total': 13, 'panels_inspected': 9, 'defects_count': 4, 'photos_count': 12},
        'dispute': {'opened_by': 1, 'reason': 'Оплатил', 'opened_at': '2026-10-29T10:00:00.000000Z'},
        'responses': [
          {'id': 1, 'status': 'declined', 'proposed_price': 3000, 'executor': {'id': 5, 'name': 'Олег'}},
          {'id': 2, 'status': 'expired', 'proposed_price': 3100, 'executor': {'id': 6, 'name': 'Игорь'}},
        ],
      });

      expect(order.status, OrderStatus.reportReady);
      expect(order.status.isAwaitingPayment, isTrue);
      expect(order.status.isFinished, isFalse);
      expect(order.payout!.cardFormatted, '2200 7000 0000 0009');
      expect(order.payout!.shortLabel, 'Карта •• 0009');
      expect(order.reportSummary!.panelsInspected, 9);
      expect(order.dispute!.reason, 'Оплатил');
      expect(order.executorDeadlineAt, isNotNull);
      expect(order.responses.map((r) => r.status.label), ['отказался', 'не успел']);
      // без responses_count — считаем по списку
      expect(order.responsesCount, 2);
      expect(orderStatusFromApi('payment_sent'), OrderStatus.paymentSent);
      expect(orderStatusFromApi('disputed'), OrderStatus.disputed);
    });

    test('responses_count важнее длины списка: исполнителю приходит только свой отклик', () {
      final order = Order.fromJson({
        'id': 2,
        'status': 'awaiting_executor',
        'brand': 'Kia',
        'model': 'Rio',
        'customer': {'id': 1, 'name': 'Андрей'},
        'responses': [
          {'id': 7, 'status': 'pending', 'proposed_price': 3000, 'executor': {'id': 5, 'name': 'Олег'}},
        ],
        'responses_count': 3,
      });

      expect(order.responses, hasLength(1));
      expect(order.responsesCount, 3);
      // новый список без числа — счётчик снова по списку, а не устаревший
      expect(order.copyWith(responses: const []).responsesCount, 0);
    });

    test('таймер дедлайна', () {
      final now = DateTime(2026, 10, 28, 12);
      expect(DeadlineCountdown.remainingLabel(now.add(const Duration(hours: 5, minutes: 12)), now), '5 ч 12 мин');
      expect(DeadlineCountdown.remainingLabel(now.add(const Duration(minutes: 40)), now), '40 мин');
      expect(DeadlineCountdown.remainingLabel(now.subtract(const Duration(minutes: 1)), now), isNull);
    });
  });

  testWidgets('заказчик: отчёт готов — сумма, реквизиты, сводка без вердикта, «Я оплатил»', (tester) async {
    final repo = MockOrderRepository(orders: [inspection(OrderStatus.reportReady)]);
    await open(tester, () => InspectionOrderDetailScreen(store: store(repo), orderId: 3001));

    expect(find.text('3 500 ₽'), findsWidgets);
    expect(find.text('2200 7000 0000 0009'), findsOneWidget);
    expect(find.textContaining('Осмотрено 13 из 13'), findsOneWidget);
    // вердикт до оплаты не показываем, даже если он пришёл
    expect(find.text('Не рекомендую'), findsNothing);

    await tester.tap(find.text('Я оплатил'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Да, я оплатил'));
    await tester.pumpAndSettle();

    expect(find.text('ЖДЁМ ПОДТВЕРЖДЕНИЯ'), findsOneWidget);
    expect(find.textContaining('Ждём, пока исполнитель подтвердит'), findsOneWidget);
    expect((await repo.fetchOrder(3001)).status, OrderStatus.paymentSent);
  });

  testWidgets('заказчик: спор, если исполнитель не подтверждает', (tester) async {
    final repo = MockOrderRepository(orders: [inspection(OrderStatus.paymentSent)]);
    await open(tester, () => InspectionOrderDetailScreen(store: store(repo), orderId: 3001));

    await tester.tap(find.text('Исполнитель не подтверждает — открыть спор'));
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(ElevatedButton, 'Открыть спор');
    // без причины спор не отправляется
    expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Перевёл вчера, подтверждения нет');
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    // плашка статуса и заголовок секции
    expect(find.text('СПОР'), findsNWidgets(2));
    expect(find.text('Вы открыли спор'), findsOneWidget);
    expect(find.text('Перевёл вчера, подтверждения нет'), findsOneWidget);
  });

  testWidgets('исполнитель: «Оплату получил» открывает отчёт заказчику', (tester) async {
    final repo = MockOrderRepository(orders: [inspection(OrderStatus.paymentSent)]);
    await open(tester, () => AssignedInspectionScreen(store: store(repo), orderId: 3001));

    expect(find.textContaining('Заказчик отметил оплату'), findsOneWidget);
    await tester.tap(find.text('Оплату получил'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Да, оплату получил'));
    await tester.pumpAndSettle();

    expect(find.text('ОТЧЁТ ПОЛУЧЕН'), findsOneWidget);
    expect(find.text('Оплату получил'), findsNothing);
    final order = await repo.fetchOrder(3001);
    expect(order.status, OrderStatus.completed);
    expect(order.payout, isNull);
  });

  testWidgets('исполнитель: таймер и отказ возвращают заказ к откликам', (tester) async {
    final repo = MockOrderRepository(
      orders: [inspection(OrderStatus.scheduled, deadline: DateTime.now().add(const Duration(hours: 20)))],
    );
    await open(tester, () => AssignedInspectionScreen(store: store(repo), orderId: 3001));

    expect(find.textContaining('Осталось'), findsOneWidget);
    await tester.tap(find.text('Отказаться от заказа'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Отказаться'));
    await tester.pumpAndSettle();

    // экран закрылся — заказ больше не наш
    expect(find.text('открыть'), findsOneWidget);
    final order = await repo.fetchOrder(3001);
    expect(order.status, OrderStatus.awaitingExecutor);
    expect(order.executor, isNull);
  });

  testWidgets('исполнитель: отчёт готов — ждём оплату, можно поправить', (tester) async {
    final repo = MockOrderRepository(orders: [inspection(OrderStatus.reportReady)]);
    await open(tester, () => AssignedInspectionScreen(store: store(repo), orderId: 3001));

    expect(find.textContaining('Ждём оплату от заказчика'), findsOneWidget);
    expect(find.text('Поправить отчёт'), findsOneWidget);
    expect(find.text('Отказаться от заказа'), findsNothing);
  });
}
