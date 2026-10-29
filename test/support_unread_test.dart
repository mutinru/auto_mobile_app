import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_chat_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/chat_message.dart';
import 'package:auto_podbor_mobile/models/chat_role.dart';
import 'package:auto_podbor_mobile/screens/intent_screen.dart';
import 'package:auto_podbor_mobile/screens/my_orders_screen.dart';
import 'package:auto_podbor_mobile/screens/support_chat_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/state/support_chat_scope.dart';
import 'package:auto_podbor_mobile/state/support_unread.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/unread_badge.dart';

/// Бейдж непрочитанных поддержки (SupportUnread + SupportUnreadBadge).
void main() {
  // ответ оператора, который ещё не читали
  final reply = ChatMessage(
    id: 1,
    body: 'Посмотрели ваш заказ',
    senderRole: ChatRole.support,
    senderName: 'Поддержка',
    createdAt: DateTime(2026, 10, 29, 12),
  );

  group('SupportUnread', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('гость — 0 и без запроса; вошёл — число с сервера; вышел — 0', () async {
      final auth = AuthService();
      final repo = MockChatRepository(supportUnread: 3)..failUnread = true;
      final unread = SupportUnread(auth, repo)..start();
      // гость: запрос упал бы, но его нет — 0 без ошибок
      await unread.refresh();
      expect(unread.count, 0);

      repo.failUnread = false;
      auth.debugSetToken('t');
      await unread.refresh();
      expect(unread.count, 3);

      auth.expireSession();
      expect(unread.count, 0);
      unread.dispose();
    });

    test('нет сети — остаётся прежнее число', () async {
      final auth = AuthService()..debugSetToken('t');
      final repo = MockChatRepository(supportUnread: 2);
      final unread = SupportUnread(auth, repo)..start();
      await unread.refresh();
      expect(unread.count, 2);

      repo.failUnread = true;
      await unread.refresh();
      expect(unread.count, 2);
      unread.dispose();
    });
  });

  group('бейдж', () {
    Future<SupportUnread> pump(
      WidgetTester tester,
      Widget home, {
      required MockChatRepository repo,
    }) async {
      final auth = AuthService()..debugSetToken('t');
      // dispose — в конце теста: таймер опроса переживёт addTearDown
      final unread = SupportUnread(auth, repo)..start();
      await unread.refresh();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        builder: (_, child) => SupportChatScope(
          auth: auth,
          repository: () => repo,
          unread: unread,
          child: child!,
        ),
        home: home,
      ));
      await tester.pumpAndSettle();
      return unread;
    }

    final intent = IntentScreen(onChoose: (_) {});

    testWidgets('стартовый экран: «Поддержка» с числом, при 0 — без', (tester) async {
      final repo = MockChatRepository(supportUnread: 2);
      final unread = await pump(tester, intent, repo: repo);
      expect(find.widgetWithText(UnreadBadge, '2'), findsOneWidget);

      repo.supportUnread = 0;
      await unread.refresh();
      await tester.pump();
      expect(find.byType(UnreadBadge), findsNothing);
      unread.dispose();
    });

    testWidgets('шторка: «2 новых сообщения», после чата бейдж гаснет', (tester) async {
      final repo = MockChatRepository(supportUnread: 2, messages: [reply]);
      final unread = await pump(tester, intent, repo: repo);

      await tester.tap(find.text('Поддержка'));
      await tester.pumpAndSettle();
      expect(find.text('2 новых сообщения от поддержки'), findsOneWidget);

      await tester.tap(find.text('Написать в чат'));
      await tester.pumpAndSettle();
      expect(find.byType(SupportChatScreen), findsOneWidget);
      // чат отметил прочитанным ответ оператора
      expect(repo.lastReadId, reply.id);

      Navigator.of(tester.element(find.byType(SupportChatScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(UnreadBadge), findsNothing);
      // экран чата опрашивает сервер — снимаем его до конца теста
      await tester.pumpWidget(const SizedBox());
      unread.dispose();
    });

    testWidgets('«Мои заказы»: бейдж на иконке профиля', (tester) async {
      final store = OrderStore(
        MockOrderRepository(),
        catalog: MockCarCatalogRepository(),
        cities: MockCityRepository(),
      );
      final unread = await pump(
        tester,
        MyOrdersScreen(store: store, onProfile: () {}),
        repo: MockChatRepository(supportUnread: 1),
      );
      expect(find.widgetWithText(UnreadBadge, '1'), findsOneWidget);
      unread.dispose();
    });

    testWidgets('больше 99 — «99+»', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: UnreadBadge(150)),
      ));
      expect(find.text('99+'), findsOneWidget);
    });
  });
}
