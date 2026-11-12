import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/phone_input.dart';

import 'support/stores.dart';

/// Телефон продавца кандидата — заметка подборщика: ему номер с
/// «Позвонить» и «Скопировать» и правка, заказчику — ничего.
void main() {
  const customer = UserSummary(id: 1, name: 'Максим К.');
  const executor = UserSummary(id: 10, name: 'Игорь В.');

  OrderCar car({String? phone}) => OrderCar(
    id: 71,
    brand: 'Skoda',
    model: 'Octavia',
    year: 2020,
    vinMasked: '··· 000071',
    inspectionId: 501,
    inspectionStatus: 'in_progress',
    sellerPhone: phone,
  );

  Order selection({String? phone}) => Order(
    id: 3301,
    status: OrderStatus.inspecting,
    brand: 'Skoda',
    model: 'Octavia',
    yearFrom: 2019,
    customer: customer,
    executor: executor,
    price: 20000,
    cars: [car(phone: phone)],
  );

  Future<MockOrderRepository> pump(
    WidgetTester tester,
    Order order, {
    required bool asExecutor,
  }) async {
    final repo = MockOrderRepository(orders: [order]);
    final auth = AuthService()
      ..debugSetToken('t')
      ..debugSetUser(
        asExecutor
            ? const CurrentUser(id: 10, name: 'Игорь В.', email: 'i@ex.com')
            : const CurrentUser(id: 1, name: 'Максим К.', email: 'm@ex.com'),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OrderDetailScreen(
          store: mockStore(
            orders: repo,
          ),
          orderId: order.id,
          viewerIsCustomer: !asExecutor,
          auth: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  test('seller_phone разбирается у кандидата', () {
    final parsed = OrderCar.fromJson({
      'id': 1,
      'brand': 'Skoda',
      'model': 'Octavia',
      'year': 2020,
      'vin_masked': '··· 000001',
      'seller_phone': '+79161234567',
    });
    expect(parsed.sellerPhone, '+79161234567');
  });

  testWidgets('подборщик видит номер, «Позвонить» и «Скопировать»', (
    tester,
  ) async {
    await pump(tester, selection(phone: '+79161234567'), asExecutor: true);

    expect(find.text('+7 916 123 45 67'), findsOneWidget);
    expect(find.text('Продавец · только для вас'), findsOneWidget);
    expect(find.byTooltip('Позвонить'), findsOneWidget);
    expect(find.byTooltip('Скопировать'), findsOneWidget);
  });

  testWidgets('заказчику номер не показывается, даже если пришёл', (
    tester,
  ) async {
    await pump(tester, selection(phone: '+79161234567'), asExecutor: false);

    expect(find.text('+7 916 123 45 67'), findsNothing);
    expect(find.textContaining('Телефон продавца'), findsNothing);
  });

  testWidgets('подборщик добавляет номер, меняет и удаляет его', (
    tester,
  ) async {
    await pump(tester, selection(), asExecutor: true);

    await tester.tap(find.text('Телефон продавца · только для вас'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(PhoneField),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '91612');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Телефон продавца — 10 цифр после +7'), findsOneWidget);

    await tester.enterText(field, '9161234567');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('+7 916 123 45 67'), findsOneWidget);

    await tester.tap(find.text('+7 916 123 45 67'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить номер'));
    await tester.pumpAndSettle();
    expect(find.text('+7 916 123 45 67'), findsNothing);
    expect(find.text('Телефон продавца · только для вас'), findsOneWidget);
  });
}
