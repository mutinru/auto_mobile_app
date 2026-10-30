import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_notification_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/app_notification.dart';
import 'package:auto_podbor_mobile/models/notification_type.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/screens/assigned_inspection_screen.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/screens/my_orders_screen.dart';
import 'package:auto_podbor_mobile/screens/notifications_screen.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/notification_scope.dart';
import 'package:auto_podbor_mobile/state/notification_unread.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/notification_bell.dart';
import 'package:auto_podbor_mobile/widgets/unread_badge.dart';

/// Лента уведомлений: модель, бейдж колокольчика, экран и переход к заказу.
void main() {
  // заказы из общей фикстуры MockOrderRepository
  const inspectionOrderId = 2051;
  const selectionOrderId = 2041;

  final now = DateTime.now();

  AppNotification note(
    String id, {
    NotificationType type = NotificationType.responseReceived,
    String title = 'Новый отклик',
    int? orderId = selectionOrderId,
    OrderKind kind = OrderKind.selection,
    bool customer = true,
    bool read = false,
    DateTime? at,
  }) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: 'Текст $id',
    orderId: orderId,
    orderKind: kind,
    viewerIsCustomer: customer,
    readAt: read ? now : null,
    createdAt: at ?? now,
  );

  OrderStore orders() => OrderStore(
    MockOrderRepository(),
    catalog: MockCarCatalogRepository(),
    cities: MockCityRepository(),
  );

  group('модель', () {
    test('тип и роль из JSON, неизвестный тип — unknown', () {
      final n = AppNotification.fromJson({
        'id': 'a',
        'type': 'payment_sent',
        'title': 'Заказчик отметил оплату',
        'body': '…',
        'order_id': 5,
        'order_kind': 'inspection',
        'viewer_role': 'executor',
        'read_at': null,
        'created_at': '2026-10-29T19:13:51+00:00',
      });
      expect(n.type, NotificationType.paymentSent);
      expect(n.orderKind, OrderKind.inspection);
      expect(n.viewerIsCustomer, isFalse);
      expect(n.isRead, isFalse);
      expect(n.opensOrder, isTrue);

      expect(notificationTypeFromApi('from_the_future'), NotificationType.unknown);
    });

    test('без viewer_role роль берётся из типа', () {
      AppNotification parse(String type) => AppNotification.fromJson({
        'id': 'a',
        'type': type,
        'order_id': 1,
        'created_at': '2026-10-29T19:13:51+00:00',
      });
      expect(parse('report_ready').viewerIsCustomer, isTrue);
      expect(parse('executor_assigned').viewerIsCustomer, isFalse);
      // спор приходит обеим сторонам — по умолчанию заказчик
      expect(parse('dispute_opened').viewerIsCustomer, isTrue);
    });

    test('отклонённый отклик заказ не открывает', () {
      expect(note('a', type: NotificationType.responseRejected).opensOrder, isFalse);
      expect(note('b', orderId: null).opensOrder, isFalse);
    });
  });

  group('NotificationUnread', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('гость — 0; вошёл — число с сервера; нет сети — прежнее', () async {
      final auth = AuthService();
      final repo = MockNotificationRepository(items: [note('a'), note('b')]);
      final unread = NotificationUnread(auth, repo)..start();
      await unread.refresh();
      expect(unread.count, 0);

      auth.debugSetToken('t');
      await unread.refresh();
      expect(unread.count, 2);

      repo.failUnread = true;
      await unread.refresh();
      expect(unread.count, 2);

      auth.expireSession();
      expect(unread.count, 0);
      unread.dispose();
    });
  });

  group('экран', () {
    late MockNotificationRepository repo;
    late NotificationUnread unread;

    Future<void> pump(WidgetTester tester, Widget home) async {
      final auth = AuthService()..debugSetToken('t');
      // dispose — в конце теста: таймер опроса переживёт addTearDown
      unread = NotificationUnread(auth, repo)..start();
      await unread.refresh();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        builder: (_, child) => NotificationScope(
          auth: auth,
          repository: () => repo,
          unread: unread,
          child: child!,
        ),
        home: home,
      ));
      await tester.pumpAndSettle();
    }

    Future<void> pumpFeed(WidgetTester tester) => pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: NotificationBell(
              onTap: () => openNotifications(context, store: orders()),
            ),
          ),
        ),
      ),
    ).then((_) async {
      await tester.tap(find.byType(NotificationBell));
      await tester.pumpAndSettle();
    });

    testWidgets('колокольчик в «Моих заказах» с числом непрочитанных', (tester) async {
      repo = MockNotificationRepository(items: [note('a'), note('b'), note('c', read: true)]);
      await pump(tester, MyOrdersScreen(store: orders(), onProfile: () {}));

      expect(
        find.descendant(of: find.byType(NotificationBell), matching: find.widgetWithText(UnreadBadge, '2')),
        findsOneWidget,
      );
      unread.dispose();
    });

    testWidgets('лента: дни, точка непрочитанного, «Прочитать все» гасит бейдж', (tester) async {
      repo = MockNotificationRepository(items: [
        note('a', title: 'Отчёт готов'),
        note('b', title: 'Новый отзыв', read: true, at: now.subtract(const Duration(days: 1))),
      ]);
      await pumpFeed(tester);

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('СЕГОДНЯ'), findsOneWidget);
      expect(find.text('ВЧЕРА'), findsOneWidget);
      expect(find.text('Отчёт готов'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot')), findsOneWidget);
      expect(find.text('1 НОВОЕ'), findsOneWidget);

      await tester.tap(find.text('Прочитать все'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
      expect(find.text('Прочитать все'), findsNothing);
      expect(unread.count, 0);
      unread.dispose();
    });

    testWidgets('тап отмечает прочитанным и открывает экран по роли и виду', (tester) async {
      repo = MockNotificationRepository(items: [
        note('customer-inspection', title: 'Отчёт готов', orderId: inspectionOrderId, kind: OrderKind.inspection),
        note('executor-inspection',
            title: 'Вас выбрали', orderId: inspectionOrderId, kind: OrderKind.inspection, customer: false),
        note('customer-selection', title: 'Новый отклик'),
      ]);
      await pumpFeed(tester);

      Future<void> openAndBack(String title, Type screen) async {
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget, reason: title);
        Navigator.of(tester.element(find.byType(screen))).pop();
        await tester.pumpAndSettle();
      }

      await openAndBack('Отчёт готов', InspectionOrderDetailScreen);
      await openAndBack('Вас выбрали', AssignedInspectionScreen);
      await openAndBack('Новый отклик', OrderDetailScreen);

      expect(repo.readCalls, ['customer-inspection', 'executor-inspection', 'customer-selection']);
      expect(find.byKey(const ValueKey('unread-dot')), findsNothing);
      expect(unread.count, 0);
      unread.dispose();
    });

    testWidgets('отклонённый отклик только читается, заказ не открывается', (tester) async {
      repo = MockNotificationRepository(items: [
        note('a', type: NotificationType.responseRejected, title: 'Отклик не принят', customer: false),
      ]);
      await pumpFeed(tester);

      await tester.tap(find.text('Отклик не принят'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.byType(OrderDetailScreen), findsNothing);
      expect(repo.readCalls, ['a']);
      unread.dispose();
    });

    testWidgets('догрузка по курсору при прокрутке', (tester) async {
      repo = MockNotificationRepository(
        pageSize: 5,
        items: [
          for (var i = 0; i < 8; i++)
            note('n$i', title: 'Уведомление $i', read: true, at: now.subtract(Duration(minutes: i))),
        ],
      );
      await pumpFeed(tester);
      expect(find.text('Уведомление 0'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Уведомление 7'), 300);
      await tester.pumpAndSettle();
      expect(find.text('Уведомление 7'), findsOneWidget);
      unread.dispose();
    });

    testWidgets('ошибка загрузки — текст и «Повторить»', (tester) async {
      repo = MockNotificationRepository(items: [note('a', title: 'Отчёт готов')])..failPage = true;
      await pumpFeed(tester);
      expect(find.text('Не удалось загрузить уведомления'), findsOneWidget);

      repo.failPage = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(find.text('Отчёт готов'), findsOneWidget);
      unread.dispose();
    });
  });
}
