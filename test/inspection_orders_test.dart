import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
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

  testWidgets('активный таб делится на секции, осмотр идёт первым',
      (tester) async {
    await tester.pumpWidget(myOrders(OrderStore(MockOrderRepository(), catalog: MockCarCatalogRepository(), cities: MockCityRepository())));
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

  testWidgets('карточка осмотра показывает дату и адрес вместо бюджета',
      (tester) async {
    await tester.pumpWidget(myOrders(OrderStore(MockOrderRepository(), catalog: MockCarCatalogRepository(), cities: MockCityRepository())));
    await tester.pumpAndSettle();

    // «Kia Rio 2019 · 64 000 км» набрано Text.rich
    expect(find.text('Kia Rio 2019 · 64 000 км', findRichText: true),
        findsOneWidget);
    expect(find.text('Завтра, 16:00'), findsOneWidget);
    expect(find.text('Химки, ул. Ленина, 5'), findsOneWidget);
    expect(find.text('НАЗНАЧЕН'), findsOneWidget);
    expect(find.text('ОСМОТР'), findsWidgets);
    // у осмотра нет бюджета — «до … ₽» рисуется только у подбора
    expect(find.textContaining('до 2 000 000'), findsNothing);
  });

  testWidgets('завершённый осмотр показывает вердикт и «другую машину»',
      (tester) async {
    await tester.pumpWidget(myOrders(OrderStore(MockOrderRepository(), catalog: MockCarCatalogRepository(), cities: MockCityRepository())));
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
    await tester.pumpWidget(myOrders(OrderStore(MockOrderRepository(), catalog: MockCarCatalogRepository(), cities: MockCityRepository())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Новый заказ'));
    await tester.pumpAndSettle();

    expect(find.text('Что нужно сделать?'), findsOneWidget);
    expect(find.text('Подобрать автомобиль'), findsOneWidget);

    await tester.tap(find.text('Осмотреть конкретную машину'));
    await tester.pumpAndSettle();

    expect(find.text('Что осмотреть'), findsOneWidget);
    expect(find.text('Разместить осмотр'), findsOneWidget);
  });

  testWidgets('деталь осмотра показывает цену заказчика и дельты откликов',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: InspectionOrderDetailScreen(
        store: OrderStore(MockOrderRepository(), catalog: MockCarCatalogRepository(), cities: MockCityRepository()),
        orderId: 2053,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('BMW X3 2017'), findsOneWidget);
    expect(find.text('Ваша цена'), findsOneWidget);
    expect(find.text('3 500 ₽'), findsNWidgets(2)); // цена заказчика и отклик в неё

    // разница с ценой заказчика у каждого отклика
    expect(find.text('−500 ₽'), findsOneWidget);
    expect(find.text('ваша цена'), findsOneWidget);
    expect(find.text('+1 000 ₽'), findsOneWidget);
    expect(find.text('Выбрать'), findsNWidgets(3));
  });

  testWidgets('выбор отклика переводит осмотр в «назначен»', (tester) async {
    final store = OrderStore(MockOrderRepository(), catalog: MockCarCatalogRepository(), cities: MockCityRepository());
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: InspectionOrderDetailScreen(store: store, orderId: 2053),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выбрать').first);
    await tester.pumpAndSettle();

    expect(find.text('НАЗНАЧЕН'), findsOneWidget);
    expect(find.text('Сергей П.'), findsOneWidget);
    expect(find.text('приедет на осмотр'), findsOneWidget);
    expect(find.text('Выбрать'), findsNothing);
  });
}
