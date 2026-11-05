import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_notification_repository.dart';
import 'package:auto_podbor_mobile/models/app_notification.dart';
import 'package:auto_podbor_mobile/models/notification_type.dart';
import 'package:auto_podbor_mobile/screens/intent_screen.dart';
import 'package:auto_podbor_mobile/state/notification_scope.dart';
import 'package:auto_podbor_mobile/state/notification_unread.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/notification_bell.dart';
import 'package:auto_podbor_mobile/widgets/unread_badge.dart';

void main() {
  /// Отдаёт экран и список того, что он успел выбрать.
  (Widget, List<AppIntent>) build() {
    final chosen = <AppIntent>[];
    return (
      MaterialApp(
        theme: AppTheme.dark,
        home: IntentScreen(onChoose: chosen.add),
      ),
      chosen,
    );
  }

  testWidgets('стартовый экран показывает вопрос и три варианта', (
    tester,
  ) async {
    final (app, _) = build();
    await tester.pumpWidget(app);

    expect(find.text('Что вас сюда привело?'), findsOneWidget);
    expect(find.text('Ищу автомобиль'), findsOneWidget);
    expect(find.text('Беру заказы на подбор'), findsOneWidget);
    expect(find.text('Просто посмотрю'), findsOneWidget);
  });

  testWidgets('вошедшему — «Куда перейти?» без онбординга (QA №19)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: IntentScreen(onChoose: (_) {}, signedIn: true),
      ),
    );

    expect(find.text('Куда перейти?'), findsOneWidget);
    expect(find.text('Что вас сюда привело?'), findsNothing);
    expect(find.textContaining('регистрац'), findsNothing);
    expect(find.text('Ищу автомобиль'), findsOneWidget);
    expect(find.text('Беру заказы на подбор'), findsOneWidget);
    expect(find.text('Просто посмотрю'), findsOneWidget);
  });

  testWidgets('гостю — вопрос и строки про регистрацию', (tester) async {
    final (app, _) = build();
    await tester.pumpWidget(app);

    expect(find.textContaining('регистрация пока не нужна'), findsOneWidget);
    expect(find.textContaining('Это не роль и не регистрация'), findsOneWidget);
  });

  testWidgets('карточка исполнителя без выдуманных цифр из макета', (
    tester,
  ) async {
    final (app, _) = build();
    await tester.pumpWidget(app);

    expect(
      find.text('Подборы и разовые осмотры — заказчики платят за работу'),
      findsOneWidget,
    );
    expect(find.textContaining('свободных заказов'), findsNothing);
    expect(find.textContaining('₽'), findsNothing);
  });

  testWidgets('«Просто посмотрю» отдаёт browse', (tester) async {
    final (app, chosen) = build();
    await tester.pumpWidget(app);

    await tester.tap(find.text('Просто посмотрю'));
    await tester.pump();

    expect(chosen, [AppIntent.browse]);
  });

  testWidgets('карточки отдают свои намерения', (tester) async {
    final (app, chosen) = build();
    await tester.pumpWidget(app);

    await tester.tap(find.text('Ищу автомобиль'));
    await tester.pump();
    await tester.tap(find.text('Беру заказы на подбор'));
    await tester.pump();

    expect(chosen, [AppIntent.buy, AppIntent.work]);
  });

  group('колокольчик', () {
    Future<NotificationUnread> pump(
      WidgetTester tester, {
      VoidCallback? onNotifications,
    }) async {
      final auth = AuthService()..debugSetToken('t');
      final repo = MockNotificationRepository(items: [note('a'), note('b')]);
      final unread = NotificationUnread(auth, repo)..start();
      await unread.refresh();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (_, child) => NotificationScope(
            auth: auth,
            repository: () => repo,
            unread: unread,
            child: child!,
          ),
          home: IntentScreen(
            onChoose: (_) {},
            onNotifications: onNotifications,
          ),
        ),
      );
      await tester.pump();
      return unread;
    }

    testWidgets('гостю (без колбэка) колокольчика нет', (tester) async {
      final unread = await pump(tester);
      expect(find.byType(NotificationBell), findsNothing);
      unread.dispose();
    });

    testWidgets('вошедшему — колокольчик с числом, тап открывает ленту', (
      tester,
    ) async {
      var opened = 0;
      final unread = await pump(tester, onNotifications: () => opened++);

      expect(find.byType(NotificationBell), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CornerBadge),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(NotificationBell));
      await tester.pump();
      expect(opened, 1);
      unread.dispose();
    });
  });
}

AppNotification note(String id) => AppNotification(
  id: id,
  type: NotificationType.unknown,
  title: 'Заголовок',
  body: 'Текст',
  createdAt: DateTime(2026),
);
