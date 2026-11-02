import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/widgets/inspection_order_parts.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/time_slot.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/screens/my_orders_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Разовый осмотр в интерфейсе заказчика (design/order-types.html).
void main() {
  Widget myOrders(OrderStore store) => MaterialApp(
    theme: AppTheme.dark,
    home: MyOrdersScreen(store: store),
  );

  testWidgets('активный таб делится на секции, осмотр идёт первым', (
    tester,
  ) async {
    await tester.pumpWidget(
      myOrders(
        OrderStore(
          MockOrderRepository(),
          catalog: MockCarCatalogRepository(),
          cities: MockCityRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ОСМОТРЫ'), findsOneWidget);
    expect(find.text('по дате'), findsOneWidget);

    // осмотры идут первыми: до подборов нужно долистать
    expect(find.text('ПОДБОРЫ'), findsNothing);
    await tester.dragUntilVisible(
      find.text('ПОДБОРЫ'),
      find.byType(ListView),
      const Offset(0, -150),
    );
    expect(find.text('ПОДБОРЫ'), findsOneWidget);
  });

  testWidgets('карточка осмотра показывает дату и адрес вместо бюджета', (
    tester,
  ) async {
    await tester.pumpWidget(
      myOrders(
        OrderStore(
          MockOrderRepository(),
          catalog: MockCarCatalogRepository(),
          cities: MockCityRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // «Kia Rio 2019 · 64 000 км» набрано Text.rich
    expect(
      find.text('Kia Rio 2019 · 64 000 км', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Завтра, 16:00'), findsOneWidget);
    expect(find.text('Химки, ул. Ленина, 5'), findsOneWidget);
    expect(find.text('НАЗНАЧЕН'), findsOneWidget);
    expect(find.text('ОСМОТР'), findsWidgets);
    // у осмотра нет бюджета — «до … ₽» рисуется только у подбора
    expect(find.textContaining('до 2 000 000'), findsNothing);
  });

  testWidgets('завершённый осмотр показывает вердикт и «другую машину»', (
    tester,
  ) async {
    await tester.pumpWidget(
      myOrders(
        OrderStore(
          MockOrderRepository(),
          catalog: MockCarCatalogRepository(),
          cities: MockCityRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Завершённые'));
    await tester.pumpAndSettle();

    // «отчёт готов» теперь значит «ждёт оплаты» — завершённый осмотр «получен»
    expect(find.text('ОТЧЁТ ПОЛУЧЕН'), findsOneWidget);
    expect(find.text('Не рекомендую'), findsOneWidget);
    expect(find.text('3 детали перекрашены, замена крыла'), findsOneWidget);
    expect(find.text('Осмотреть другую машину'), findsOneWidget);
  });

  testWidgets('«Новый заказ» открывает лист выбора вида', (tester) async {
    await tester.pumpWidget(
      myOrders(
        OrderStore(
          MockOrderRepository(),
          catalog: MockCarCatalogRepository(),
          cities: MockCityRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Новый заказ'));
    await tester.pumpAndSettle();

    expect(find.text('Что нужно сделать?'), findsOneWidget);
    expect(find.text('Подобрать автомобиль'), findsOneWidget);
    // разовый осмотр — первым, подбор — под ним
    expect(
      tester.getTopLeft(find.text('Осмотреть конкретную машину')).dy,
      lessThan(tester.getTopLeft(find.text('Подобрать автомобиль')).dy),
    );

    await tester.tap(find.text('Осмотреть конкретную машину'));
    await tester.pumpAndSettle();

    expect(find.text('Что осмотреть'), findsOneWidget);
    expect(find.text('Разместить осмотр'), findsOneWidget);
  });

  testWidgets('деталь осмотра показывает цену заказчика и дельты откликов', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionOrderDetailScreen(
          store: OrderStore(
            MockOrderRepository(),
            catalog: MockCarCatalogRepository(),
            cities: MockCityRepository(),
          ),
          orderId: 2053,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BMW X3 2017'), findsOneWidget);
    expect(find.text('Ваша цена'), findsOneWidget);
    expect(
      find.text('3 500 ₽'),
      findsNWidgets(2),
    ); // цена заказчика и отклик в неё

    // разница с ценой заказчика у каждого отклика
    expect(find.text('−500 ₽'), findsOneWidget);
    expect(find.text('ваша цена'), findsOneWidget);
    expect(find.text('+1 000 ₽'), findsOneWidget);
    expect(find.text('Выбрать'), findsNWidgets(3));
  });

  testWidgets('ссылка подписана площадкой, чужой сайт — доменом с пометкой', (
    tester,
  ) async {
    final store = OrderStore(
      MockOrderRepository(),
      catalog: MockCarCatalogRepository(),
      cities: MockCityRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionOrderDetailScreen(store: store, orderId: 2053),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Объявление на Авто.ру', findRichText: true),
      findsOneWidget,
    );

    final order = await store.createInspectionOrder(
      brand: 'Kia',
      model: 'Rio',
      year: 2019,
      mileageKm: 60000,
      city: 'Москва',
      address: 'ул. Тверская, 1',
      inspectOn: DateTime.now().add(const Duration(days: 1)),
      timeSlot: TimeSlot.day,
      askingPrice: 3500,
      listingUrl: 'www.example.com/car/1',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        // ключ — иначе виджет переиспользует состояние прошлого заказа
        home: InspectionOrderDetailScreen(
          key: ValueKey(order.id),
          store: store,
          orderId: order.id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('example.com · незнакомый сайт', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('выбор отклика переводит осмотр в «назначен»', (tester) async {
    final store = OrderStore(
      MockOrderRepository(),
      catalog: MockCarCatalogRepository(),
      cities: MockCityRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionOrderDetailScreen(store: store, orderId: 2053),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выбрать').first);
    await tester.pumpAndSettle();

    expect(find.text('НАЗНАЧЕН'), findsOneWidget);
    expect(find.text('Сергей П.'), findsOneWidget);
    expect(find.text('приедет на осмотр'), findsOneWidget);
    expect(find.text('Выбрать'), findsNothing);
  });

  testWidgets('до выбора исполнитель видит площадку, но не ссылку', (
    tester,
  ) async {
    Future<void> show(Order order) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: InspectionOrderSummary(
              order: order,
              priceLabel: 'Ваш гонорар',
              price: 3500,
            ),
          ),
        ),
      );
    }

    const base = Order(
      id: 1,
      kind: OrderKind.inspection,
      status: OrderStatus.awaitingExecutor,
      brand: 'Kia',
      model: 'Rio',
      customer: UserSummary(id: 1, name: 'Андрей С.'),
      timeSlot: TimeSlot.day,
      hasListing: true,
      listingSite: 'Авито',
    );
    await show(base);
    expect(
      find.textContaining(
        'Объявление на Авито · откроется после выбора',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsNothing);

    // чужой сайт не называем вовсе
    await show(
      const Order(
        id: 2,
        kind: OrderKind.inspection,
        status: OrderStatus.awaitingExecutor,
        brand: 'Kia',
        model: 'Rio',
        customer: UserSummary(id: 1, name: 'Андрей С.'),
        timeSlot: TimeSlot.day,
        hasListing: true,
      ),
    );
    expect(
      find.textContaining('Объявление на другом сайте', findRichText: true),
      findsOneWidget,
    );
  });

  test('пробег осмотра необязателен: машина без пробега разбирается', () async {
    final car = OrderCar.fromJson(const {
      'id': 1,
      'brand': 'Kia',
      'model': 'Rio',
      'year': 2019,
      'vin_masked': '—',
      'mileage_km': null,
    });
    expect(car.mileageKm, isNull);

    final store = OrderStore(
      MockOrderRepository(),
      catalog: MockCarCatalogRepository(),
      cities: MockCityRepository(),
    );
    final order = await store.createInspectionOrder(
      brand: 'Kia',
      model: 'Rio',
      year: 2019,
      city: 'Москва',
      address: 'ул. Тверская, 1',
      inspectOn: DateTime.now().add(const Duration(days: 1)),
      timeSlot: TimeSlot.day,
      askingPrice: 3500,
    );
    expect(order.mileageTo, isNull);
    expect(order.cars.single.mileageKm, isNull);
  });
}
