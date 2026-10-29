import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/screens/my_orders_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

void main() {
  testWidgets('My orders screen lists orders and opens detail', (tester) async {
    final store = OrderStore(MockOrderRepository(), catalog: MockCarCatalogRepository(), cities: MockCityRepository());

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: MyOrdersScreen(store: store),
    ));
    await tester.pumpAndSettle();

    // активный таб начинается с секции «Осмотры», подборы ниже — до них
    // нужно долистать
    await tester.dragUntilVisible(
      find.text('Kia Sportage 2021+'),
      find.byType(ListView),
      const Offset(0, -120),
    );
    expect(find.text('Kia Sportage 2021+'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Toyota Camry 2018+'),
      find.byType(ListView),
      const Offset(0, 120),
    );
    expect(find.text('Toyota Camry 2018+'), findsOneWidget);

    await tester.tap(find.text('Toyota Camry 2018+'));
    await tester.pumpAndSettle();

    expect(find.text('Заказ #2041'), findsOneWidget);
  });
}
