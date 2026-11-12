import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_notification_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/assigned_inspection_screen.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/screens/auto_refresh.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/notification_scope.dart';
import 'package:auto_podbor_mobile/state/notification_unread.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/app_ui.dart';

/// «Сервер»: заказ можно поменять между запросами, как это делает другая
/// сторона или поддержка. Отметку оплаты можно придержать.
class _ServerRepo extends MockOrderRepository {
  _ServerRepo(this.server);

  Order server;
  int fetches = 0;
  Completer<void>? holdPayment;

  @override
  Future<Order> fetchOrder(int id) async {
    fetches++;
    return MockOrderRepository.withActions(server);
  }

  @override
  Future<Order> markPaymentSent(int orderId) async {
    await holdPayment?.future;
    return server = MockOrderRepository.withActions(
      server.copyWith(status: OrderStatus.paymentSent),
    );
  }
}

/// Экран заказа перечитывает заказ сам и по жесту (QA №33).
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');
  const executor = UserSummary(id: 10, name: 'Максим К.');

  Order order(OrderStatus status, {OrderKind kind = OrderKind.inspection}) =>
      Order(
        id: 3001,
        kind: kind,
        status: status,
        brand: 'Hyundai',
        model: 'Solaris',
        yearFrom: 2018,
        customer: customer,
        executor: executor,
        price: 3500,
        askingPrice: 3500,
        cities: const ['Москва'],
      );

  OrderStore store(MockOrderRepository repo) => OrderStore(
    repo,
    catalog: MockCarCatalogRepository(),
    cities: MockCityRepository(),
  );

  Finder pill(OrderStatus status) => find.descendant(
    of: find.byType(Pill),
    matching: find.text(status.labelFor(OrderKind.inspection).toUpperCase()),
  );

  late GlobalKey<NavigatorState> navigator;

  /// Экран — поверх «домашнего», с наблюдателем маршрутов, как в приложении.
  Future<void> open(
    WidgetTester tester,
    Widget Function() screen, {
    NotificationUnread? unread,
    AuthService? auth,
  }) async {
    navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.dark,
        navigatorObservers: [appRouteObserver],
        builder: (_, child) => unread == null
            ? child!
            : NotificationScope(auth: auth!, unread: unread, child: child!),
        home: const Scaffold(body: SizedBox()),
      ),
    );
    navigator.currentState!.push(MaterialPageRoute(builder: (_) => screen()));
    await tester.pumpAndSettle();
  }

  Widget customerScreen(_ServerRepo repo) => InspectionOrderDetailScreen(
    store: store(repo),
    orderId: 3001,
    viewerIsCustomer: true,
  );

  Future<void> pullDown(WidgetTester tester) async {
    await tester.fling(find.byType(ListView), const Offset(0, 500), 1000);
    await tester.pumpAndSettle();
  }

  testWidgets('заказчик тянет вниз — спор решён без выхода с экрана', (
    tester,
  ) async {
    final repo = _ServerRepo(order(OrderStatus.disputed));
    await open(tester, () => customerScreen(repo));
    expect(pill(OrderStatus.disputed), findsOneWidget);

    repo.server = order(OrderStatus.completed);
    await pullDown(tester);

    expect(pill(OrderStatus.completed), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('возврат на экран (закрыли чат поддержки) перечитывает', (
    tester,
  ) async {
    final repo = _ServerRepo(order(OrderStatus.disputed));
    await open(tester, () => customerScreen(repo));

    navigator.currentState!.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('чат'))),
    );
    await tester.pumpAndSettle();
    repo.server = order(OrderStatus.completed);
    // пока сверху чат, опрос не ходит
    final fetches = repo.fetches;
    await tester.pump(AutoRefresh.pollInterval);
    expect(repo.fetches, fetches);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(pill(OrderStatus.completed), findsOneWidget);
  });

  testWidgets('новое уведомление перечитывает, прочитанное — нет', (
    tester,
  ) async {
    final auth = AuthService()..debugSetToken('t');
    final unread = NotificationUnread(auth, MockNotificationRepository())
      ..report(2);
    addTearDown(unread.dispose);
    final repo = _ServerRepo(order(OrderStatus.reportReady));
    await open(
      tester,
      () => AssignedInspectionScreen(store: store(repo), orderId: 3001),
      unread: unread,
      auth: auth,
    );
    final fetches = repo.fetches;

    unread.report(1);
    await tester.pumpAndSettle();
    expect(repo.fetches, fetches);

    repo.server = order(OrderStatus.paymentSent);
    unread.report(2);
    await tester.pumpAndSettle();

    expect(repo.fetches, fetches + 1);
    expect(pill(OrderStatus.paymentSent), findsOneWidget);
  });

  testWidgets('опрос — страховка раз в pollInterval; после закрытия — тишина', (
    tester,
  ) async {
    final repo = _ServerRepo(order(OrderStatus.paymentSent));
    await open(tester, () => customerScreen(repo));

    repo.server = order(OrderStatus.completed);
    // основной сигнал — уведомление; таймер редкий (ревью №42): заказ
    // целиком за 30 с не перечитываем
    final opened = repo.fetches;
    const early = Duration(seconds: 30);
    await tester.pump(early);
    expect(repo.fetches, opened);
    await tester.pump(AutoRefresh.pollInterval - early);
    await tester.pump();
    expect(pill(OrderStatus.completed), findsOneWidget);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    final fetches = repo.fetches;
    await tester.pump(AutoRefresh.pollInterval * 3);
    expect(repo.fetches, fetches);
  });

  testWidgets('во время действия опрос не затирает его результат', (
    tester,
  ) async {
    final repo = _ServerRepo(order(OrderStatus.reportReady))
      ..holdPayment = Completer<void>();
    await open(tester, () => customerScreen(repo));

    await tester.tap(find.text('Я оплатил'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Да, я оплатил'));
    await tester.pump();

    final fetches = repo.fetches;
    await tester.pump(AutoRefresh.pollInterval);
    expect(repo.fetches, fetches, reason: 'идёт отметка оплаты');

    repo.holdPayment!.complete();
    await tester.pumpAndSettle();
    expect(pill(OrderStatus.paymentSent), findsOneWidget);
  });

  testWidgets('исполнитель тоже тянет вниз', (tester) async {
    final repo = _ServerRepo(order(OrderStatus.paymentSent));
    await open(
      tester,
      () => AssignedInspectionScreen(store: store(repo), orderId: 3001),
    );

    repo.server = order(OrderStatus.disputed);
    await pullDown(tester);

    expect(pill(OrderStatus.disputed), findsOneWidget);
  });

  testWidgets('карточка подбора тянется вниз', (tester) async {
    final repo = _ServerRepo(
      order(OrderStatus.sourcing, kind: OrderKind.selection),
    );
    await open(
      tester,
      () => OrderDetailScreen(
        store: store(repo),
        orderId: 3001,
        viewerIsCustomer: true,
      ),
    );
    final fetches = repo.fetches;

    await pullDown(tester);

    expect(repo.fetches, fetches + 1);
  });
}
