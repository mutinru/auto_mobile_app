import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/data/mock_verification_repository.dart';
import 'package:auto_podbor_mobile/screens/profile_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

void main() {
  /// Блок «Выполнять заказы» ниже сгиба: в стандартные 800×600 ленивый
  /// ListView его не строит.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  Widget app({required bool required}) => MaterialApp(
    theme: AppTheme.dark,
    home: ProfileScreen(
      auth: AuthService(),
      store: OrderStore(MockOrderRepository()),
      verification: MockVerificationRepository(required: required),
      onMyOrders: () {},
      onNearbyOrders: () {},
    ),
  );

  testWidgets('верификация не обязательна — пункта про неё в профиле нет', (
    tester,
  ) async {
    tallScreen(tester);
    await tester.pumpWidget(app(required: false));
    await tester.pumpAndSettle();

    // в моке у пользователя есть взятые заказы, поэтому блок ведёт к ним
    expect(find.text('Выполнять заказы'), findsOneWidget);
    expect(find.text('Пройти верификацию'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('верификация обязательна — блок исполнителя закрыт', (
    tester,
  ) async {
    tallScreen(tester);
    await tester.pumpWidget(app(required: true));
    await tester.pumpAndSettle();

    expect(find.text('Выполнять заказы'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
