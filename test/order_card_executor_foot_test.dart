import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/order_card.dart';

/// Подвал карточки: заказчику — исполнитель, исполнителю во «Взятых» —
/// заказчик, а не он сам.
void main() {
  const order = Order(
    id: 65,
    status: OrderStatus.sourcing,
    brand: 'Skoda',
    model: 'Octavia',
    yearFrom: 2019,
    customer: UserSummary(id: 1, name: 'Максим К.'),
    executor: UserSummary(id: 10, name: 'Игорь В.'),
    price: 20000,
  );

  Future<void> pump(WidgetTester tester, {required bool asExecutor}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: OrderCard(order: order, onTap: () {}, asExecutor: asExecutor),
          ),
        ),
      );

  testWidgets('заказчик видит исполнителя', (tester) async {
    await pump(tester, asExecutor: false);
    expect(find.textContaining('Игорь В.'), findsOneWidget);
    expect(find.textContaining('Максим К.'), findsNothing);
  });

  testWidgets('исполнитель видит заказчика, а не себя', (tester) async {
    await pump(tester, asExecutor: true);
    expect(
      find.text('Максим К. · заказчик', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Игорь В.'), findsNothing);
    expect(find.textContaining('20 000'), findsOneWidget);
  });
}
