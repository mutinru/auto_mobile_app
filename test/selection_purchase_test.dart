import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_outcome.dart';
import 'package:auto_podbor_mobile/models/inspection_verdict.dart';
import 'package:auto_podbor_mobile/models/notification_type.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_action.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Закрытие подбора: исполнитель сообщает о покупке, заказчик отвечает
/// «Да» (обычное завершение) или «Нет», сутки после закрытия заказчик может
/// выбрать другую купленную машину. Правила — с сервера (canReportPurchase,
/// purchaseEditableUntil), экран их только показывает.
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');
  const executor = UserSummary(id: 10, name: 'Игорь В.');

  const rio = OrderCar(
    id: 81,
    brand: 'Kia',
    model: 'Rio',
    year: 2019,
    vinMasked: '··· 111111',
    inspectionId: 601,
    inspectionStatus: 'completed',
    verdict: InspectionVerdict.recommended,
  );
  const solaris = OrderCar(
    id: 82,
    brand: 'Hyundai',
    model: 'Solaris',
    year: 2020,
    vinMasked: '··· 222222',
    inspectionId: 602,
    inspectionStatus: 'completed',
    verdict: InspectionVerdict.withReservations,
  );
  // осмотр идёт — сообщить о его покупке нельзя
  const polo = OrderCar(
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
    PurchaseReport? report,
    bool canReport = false,
    DateTime? editableUntil,
    List<OrderCar> cars = const [rio, solaris, polo],
  }) => Order(
    id: 3101,
    status: status,
    brand: 'Kia',
    model: 'Rio',
    yearFrom: 2018,
    customer: customer,
    executor: executor,
    price: 15000,
    cars: cars,
    purchaseReport: report,
    actions: {if (canReport) OrderAction.reportPurchase},
    purchaseEditableUntil: editableUntil,
  );

  Future<MockOrderRepository> pump(
    WidgetTester tester,
    Order order, {
    bool viewerIsCustomer = true,
  }) async {
    // высокий экран: ленивый список строит всё, и «кнопки нет» не путается
    // с «кнопка ниже экрана»
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = MockOrderRepository(orders: [order]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OrderDetailScreen(
          store: OrderStore(
            repo,
            catalog: MockCarCatalogRepository(),
            cities: MockCityRepository(),
          ),
          orderId: order.id,
          viewerIsCustomer: viewerIsCustomer,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  /// Список карточки ленивый: нижние кнопки строятся, только когда до них
  /// докрутили.
  Future<void> scrollTo(WidgetTester tester, String text) =>
      tester.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: find.byType(Scrollable).first,
      );

  Future<void> tapVisible(WidgetTester tester, String text) async {
    await scrollTo(tester, text);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  test('новые поля заказа и типы уведомлений разбираются', () {
    final order = Order.fromJson({
      'id': 5,
      'kind': 'selection',
      'status': 'inspecting',
      'brand': 'Kia',
      'model': 'Rio',
      'customer': {'id': 1, 'name': 'А'},
      'purchase_report': {
        'car_id': 81,
        'reported_at': '2026-11-11T09:00:00.000000Z',
      },
      'can_report_purchase': false,
      'purchase_editable_until': '2026-11-12T09:00:00.000000Z',
    });
    expect(order.purchaseReport!.carId, 81);
    expect(
      order.purchaseReport!.reportedAt!.isAtSameMomentAs(
        DateTime.utc(2026, 11, 11, 9),
      ),
      isTrue,
    );
    expect(order.canReportPurchase, isFalse);
    expect(order.purchaseEditableUntil, isNotNull);

    // старый сервер полей не знает
    final bare = Order.fromJson({
      'id': 6,
      'status': 'sourcing',
      'brand': 'Kia',
      'model': 'Rio',
      'customer': {'id': 1, 'name': 'А'},
    });
    expect(bare.purchaseReport, isNull);
    expect(bare.canReportPurchase, isFalse);
    expect(bare.purchaseEditableUntil, isNull);

    expect(
      notificationTypeFromApi('purchase_reported'),
      NotificationType.purchaseReported,
    );
    expect(
      notificationTypeFromApi('purchase_reminder'),
      NotificationType.purchaseReminder,
    );
    expect(
      notificationTypeFromApi('purchase_report_declined'),
      NotificationType.purchaseReportDeclined,
    );
    expect(
      notificationTypeFromApi('purchase_changed'),
      NotificationType.purchaseChanged,
    );
    expect(NotificationType.purchaseReported.defaultViewerIsCustomer, isTrue);
    expect(
      NotificationType.purchaseReportDeclined.defaultViewerIsCustomer,
      isFalse,
    );
    expect(NotificationType.purchaseChanged.defaultViewerIsCustomer, isFalse);
  });

  testWidgets('исполнитель сообщает о покупке машины с вердиктом', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      selection(canReport: true),
      viewerIsCustomer: false,
    );

    await tapVisible(tester, 'Заказчик купил машину');
    expect(find.text('Какую машину купил заказчик?'), findsOneWidget);
    // идущий осмотр в листе не предлагается
    expect(find.text('VIN ··· 333333'), findsNothing);

    await tester.tap(find.text('VIN ··· 222222'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сообщить заказчику'));
    await tester.pumpAndSettle();

    expect(repo.lastReportedCarId, solaris.id);
    expect(find.text('Заказчик получит уведомление'), findsOneWidget);
    expect(
      find.text('Ждём подтверждения заказчика: Hyundai Solaris 2020.'),
      findsOneWidget,
    );
    expect(find.text('Заказчик купил машину'), findsNothing);
  });

  testWidgets('без разрешения сервера кнопки у исполнителя нет', (
    tester,
  ) async {
    await pump(tester, selection(), viewerIsCustomer: false);
    expect(find.text('Заказчик купил машину'), findsNothing);
  });

  testWidgets('заказчику кнопки исполнителя нет', (tester) async {
    await pump(tester, selection(canReport: true));
    expect(find.text('Заказчик купил машину'), findsNothing);
  });

  testWidgets('заказчик отвечает «Да» — подбор закрыт с этой машиной', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      selection(report: PurchaseReport(carId: rio.id)),
    );

    expect(
      find.text(
        'Игорь В. отметил покупку Kia Rio 2019. Подтвердите — и сможете '
        'оценить подборщика.',
      ),
      findsOneWidget,
    );
    // главная кнопка — «Да, купил»; свою покупку можно отметить и другой
    await scrollTo(tester, 'Купил другую машину');
    expect(find.text('Зафиксировать покупку'), findsNothing);

    await tapVisible(tester, 'Да, купил');

    final order = await repo.fetchOrder(3101);
    expect(order.status, OrderStatus.completed);
    expect(order.purchaseReport, isNull);
    expect(
      order.cars.firstWhere((c) => c.id == rio.id).inspectionOutcome,
      InspectionOutcome.purchased,
    );
    expect(find.text('Да, купил'), findsNothing);
    await scrollTo(tester, 'Изменить покупку');
  });

  testWidgets('заказчик отвечает «Нет» — сообщение снято', (tester) async {
    final repo = await pump(
      tester,
      selection(report: PurchaseReport(carId: rio.id)),
    );

    await tapVisible(tester, 'Нет, не покупал');
    expect(find.text('Не покупали Kia Rio 2019?'), findsOneWidget);
    // кнопка подтверждения в листе — последняя с этим текстом
    await tester.tap(find.text('Нет, не покупал').last);
    await tester.pumpAndSettle();

    final order = await repo.fetchOrder(3101);
    expect(order.purchaseReport, isNull);
    expect(order.status, OrderStatus.inspecting);
    expect(find.textContaining('отметил покупку'), findsNothing);
    await scrollTo(tester, 'Зафиксировать покупку');
  });

  testWidgets('исполнитель ждёт ответа — у заказчика без ответа нет кнопок', (
    tester,
  ) async {
    await pump(
      tester,
      selection(report: PurchaseReport(carId: rio.id)),
      viewerIsCustomer: false,
    );
    expect(find.text('Да, купил'), findsNothing);
    expect(find.text('Нет, не покупал'), findsNothing);
    expect(
      find.text('Ждём подтверждения заказчика: Kia Rio 2019.'),
      findsOneWidget,
    );
  });

  testWidgets('перевыбор покупки в окне сервера', (tester) async {
    final repo = await pump(
      tester,
      selection(
        status: OrderStatus.completed,
        editableUntil: DateTime.now().add(const Duration(hours: 20)),
        cars: [
          rio.withOutcome(InspectionOutcome.purchased),
          solaris.withOutcome(InspectionOutcome.rejected),
        ],
      ),
    );

    await tapVisible(tester, 'Изменить покупку');
    expect(find.text('Какую машину купили?'), findsOneWidget);
    // текущий выбор отмечен — сохранить его же нельзя
    final save = find.widgetWithText(ElevatedButton, 'Сохранить');
    expect(tester.widget<ElevatedButton>(save).onPressed, isNull);

    await tester.tap(find.text('VIN ··· 222222'));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Покупка изменена'), findsOneWidget);
    final order = await repo.fetchOrder(3101);
    expect(
      order.cars.firstWhere((c) => c.id == solaris.id).inspectionOutcome,
      InspectionOutcome.purchased,
    );
    expect(
      order.cars.firstWhere((c) => c.id == rio.id).inspectionOutcome,
      InspectionOutcome.rejected,
    );
  });

  testWidgets('кандидат один — выбирать другую машину не из чего', (
    tester,
  ) async {
    await pump(
      tester,
      selection(
        report: PurchaseReport(carId: rio.id),
        cars: const [rio],
      ),
    );
    expect(find.text('Да, купил'), findsOneWidget);
    expect(find.text('Купил другую машину'), findsNothing);

    await tester.tap(find.text('Да, купил'));
    await tester.pumpAndSettle();
    // окно перевыбора открыто, но менять не на что
    expect(find.text('Изменить покупку'), findsNothing);
  });

  testWidgets('окно закрыто — «Изменить покупку» нет', (tester) async {
    await pump(
      tester,
      selection(
        status: OrderStatus.completed,
        cars: [rio.withOutcome(InspectionOutcome.purchased)],
      ),
    );
    expect(find.text('Изменить покупку'), findsNothing);
  });
}
