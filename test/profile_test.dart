import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/data/mock_verification_repository.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/screens/profile_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/executor_stats.dart';

void main() {
  /// Блок «Выполнять заказы» ниже сгиба: в стандартные 800×600 ленивый
  /// ListView его не строит.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  Widget app({required bool required, CurrentUser? user, Future<void> Function()? onLogout}) => MaterialApp(
    theme: AppTheme.dark,
    home: ProfileScreen(
      auth: user == null ? AuthService() : (AuthService()..debugSetUser(user)),
      store: OrderStore(MockOrderRepository(), catalog: MockCarCatalogRepository(), cities: MockCityRepository()),
      verification: MockVerificationRepository(required: required),
      onMyOrders: () {},
      onNearbyOrders: () {},
      onLogout: onLogout ?? () async {},
    ),
  );

  testWidgets('«Выйти» спрашивает подтверждение, «Отмена» ничего не делает', (
    tester,
  ) async {
    tallScreen(tester);
    var loggedOut = 0;
    await tester.pumpWidget(app(required: false, onLogout: () async => loggedOut++));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из аккаунта?'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из аккаунта?'), findsNothing);
    expect(loggedOut, 0);

    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    // в диалоге своя кнопка «Выйти» — последняя по дереву
    await tester.tap(find.text('Выйти').last);
    await tester.pumpAndSettle();
    expect(loggedOut, 1);
  });

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

  testWidgets('свой рейтинг исполнителя и переход к отзывам', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(
      app(
        required: false,
        user: const CurrentUser(
          id: 10,
          name: 'Максим К.',
          email: 'inspector@autopodbor.local',
          rating: 4.8,
          reviewsCount: 12,
          completedOrdersCount: 30,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('рейтинг'), findsOneWidget);
    expect(find.text('★ 4.8 · 12 отзывов · 30 заказов', findRichText: true),
        findsOneWidget);

    await tester.tap(find.byType(ExecutorStats));
    await tester.pumpAndSettle();
    expect(find.text('ОТЗЫВЫ'), findsOneWidget);
  });

  testWidgets('без отзывов — прочерк и без строки рейтинга', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(
      app(
        required: false,
        user: const CurrentUser(id: 15, name: 'Олег К.', email: 'x'),
      ),
    );
    await tester.pumpAndSettle();

    // в моке у пользователя есть взятые заказы — плашки видны
    expect(find.text('—'), findsWidgets);
    expect(find.byType(ExecutorStats), findsNothing);
  });

  testWidgets('номер телефона в профиле открывает лист смены', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(
      app(
        required: false,
        user: const CurrentUser(id: 15, name: 'Олег К.', email: 'x', phone: '+79000000002'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+7 900 000 00 02'), findsOneWidget);
    await tester.tap(find.text('Номер телефона'));
    await tester.pumpAndSettle();
    expect(find.text('Новый номер'), findsOneWidget);
  });
}
