import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/data/mock_verification_repository.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/screens/profile_screen.dart';
import 'package:auto_podbor_mobile/state/verification_status.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/theme/theme_controller.dart';
import 'package:auto_podbor_mobile/widgets/theme_switch.dart';
import 'package:auto_podbor_mobile/widgets/executor_stats.dart';

import 'support/stores.dart';

void main() {
  /// Блок «Выполнять заказы» ниже сгиба: в стандартные 800×600 ленивый
  /// ListView его не строит.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  Widget app({
    required bool required,
    CurrentUser? user,
    Future<void> Function()? onLogout,
    Future<void> Function()? onDeleteAccount,
  }) => MaterialApp(
    theme: AppTheme.dark,
    home: ProfileScreen(
      auth: user == null ? AuthService() : (AuthService()..debugSetUser(user)),
      store: mockStore(
        orders: MockOrderRepository(),
      ),
      verification: VerificationStatus(
        MockVerificationRepository(required: required),
      ),
      onMyOrders: () {},
      onNearbyOrders: () {},
      onLogout: onLogout ?? () async {},
      onDeleteAccount: onDeleteAccount ?? () async {},
    ),
  );

  testWidgets('«Выйти» спрашивает подтверждение, «Отмена» ничего не делает', (
    tester,
  ) async {
    tallScreen(tester);
    var loggedOut = 0;
    await tester.pumpWidget(
      app(required: false, onLogout: () async => loggedOut++),
    );
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

  testWidgets('«Удалить аккаунт» — с подтверждением, «Отмена» не удаляет', (
    tester,
  ) async {
    tallScreen(tester);
    var deleted = 0;
    await tester.pumpWidget(
      app(required: false, onDeleteAccount: () async => deleted++),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Удалить аккаунт'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить аккаунт?'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(deleted, 0);

    await tester.tap(find.text('Удалить аккаунт'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('удаление не прошло — текст сервера, профиль на месте', (
    tester,
  ) async {
    tallScreen(tester);
    await tester.pumpWidget(
      app(
        required: false,
        onDeleteAccount: () async => throw ApiException(
          422,
          '{"message":"Удалить аккаунт пока нельзя — сначала завершите или отмените заказы: Kia Rio 2019."}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Удалить аккаунт'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Удалить аккаунт пока нельзя'), findsOneWidget);
    // строка снова нажимается
    expect(find.text('Удалить аккаунт'), findsOneWidget);
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
    expect(
      find.text('★ 4.8 · 12 отзывов · 30 заказов', findRichText: true),
      findsOneWidget,
    );

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
        user: const CurrentUser(
          id: 15,
          name: 'Олег К.',
          email: 'x',
          phone: '+79000000002',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+7 900 000 00 02'), findsOneWidget);
    await tester.tap(find.text('Номер телефона'));
    await tester.pumpAndSettle();
    expect(find.text('Новый номер'), findsOneWidget);
  });

  group('строка «Тема» (QA 2026-11-05 №13)', () {
    Future<ThemeController> pumpWithTheme(WidgetTester tester) async {
      tallScreen(tester);
      final theme = ThemeController();
      await tester.pumpWidget(
        ThemeScope(controller: theme, child: app(required: false)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Тема'));
      await tester.pumpAndSettle();
      return theme;
    }

    testWidgets('нажатие по названию переключает тему', (tester) async {
      final theme = await pumpWithTheme(tester);
      await tester.tap(find.text('Тема'));
      await tester.pumpAndSettle();
      expect(theme.isLight, isTrue);
      await tester.tap(find.text('Тема'));
      await tester.pumpAndSettle();
      expect(theme.isLight, isFalse);
    });

    testWidgets('капсула переключает ровно один раз', (tester) async {
      final theme = await pumpWithTheme(tester);
      await tester.tap(find.byType(ThemeSwitch));
      await tester.pumpAndSettle();
      expect(theme.isLight, isTrue);
    });

    testWidgets('диктору — один переключатель, без кнопки внутри', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpWithTheme(tester);
      expect(
        tester.getSemantics(find.text('Тема')),
        matchesSemantics(
          label: 'Светлая тема\nТема',
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
          hasEnabledState: false,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      expect(find.bySemanticsLabel(RegExp('Включить')), findsNothing);
      semantics.dispose();
    });
  });
}
