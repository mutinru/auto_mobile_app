import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_notification_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/auto_refresh.dart';
import 'package:auto_podbor_mobile/screens/my_orders_screen.dart';
import 'package:auto_podbor_mobile/state/notification_scope.dart';
import 'package:auto_podbor_mobile/state/notification_unread.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

import 'support/stores.dart';

/// «Сервер»: списки можно поменять между запросами, как это делает другая
/// сторона; можно уронить следующий запрос.
class _ServerRepo extends MockOrderRepository {
  List<Order> mine = const [];
  List<Order> assigned = const [];
  int fetches = 0;
  bool fail = false;

  Future<List<Order>> _answer(List<Order> orders) async {
    fetches++;
    if (fail) throw Exception('нет сети');
    return orders;
  }

  @override
  Future<List<Order>> fetchMyOrders() => _answer(mine);

  @override
  Future<List<Order>> fetchAssignedOrders() => _answer(assigned);
}

/// «Мои заказы» и «Взятые заказы» перечитываются сами (QA 2026-11-05 №1).
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');
  const executor = UserSummary(id: 10, name: 'Максим К.');

  Order order(String model, {int id = 3001}) => Order(
    id: id,
    kind: OrderKind.inspection,
    status: OrderStatus.reportReady,
    brand: 'Hyundai',
    model: model,
    yearFrom: 2018,
    customer: customer,
    executor: executor,
    price: 3500,
    askingPrice: 3500,
    cities: const ['Москва'],
  );

  Finder card(String model) =>
      find.text('Hyundai $model 2018', findRichText: true);

  late GlobalKey<NavigatorState> navigator;

  /// Экран — поверх «домашнего», с наблюдателем маршрутов, как в приложении.
  Future<void> open(
    WidgetTester tester,
    _ServerRepo repo, {
    bool asExecutor = false,
    NotificationUnread? unread,
    AuthService? auth,
  }) async {
    final store = mockStore(
      orders: repo,
    );
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
    navigator.currentState!.push(
      MaterialPageRoute(
        builder: (_) => MyOrdersScreen(store: store, asExecutor: asExecutor),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pullDown(WidgetTester tester) async {
    await tester.fling(find.byType(ListView), const Offset(0, 500), 1000);
    await tester.pumpAndSettle();
  }

  testWidgets('новое уведомление перечитывает, прочитанное — нет', (
    tester,
  ) async {
    final auth = AuthService()..debugSetToken('t');
    final unread = NotificationUnread(auth, MockNotificationRepository())
      ..report(2);
    addTearDown(unread.dispose);
    final repo = _ServerRepo()..mine = [order('Solaris')];
    await open(tester, repo, unread: unread, auth: auth);
    final fetches = repo.fetches;

    unread.report(1);
    await tester.pumpAndSettle();
    expect(repo.fetches, fetches);

    repo.mine = [order('Creta')];
    unread.report(2);
    await tester.pumpAndSettle();

    expect(repo.fetches, fetches + 1);
    expect(card('Creta'), findsOneWidget);
  });

  testWidgets('пустой список тоже тянется вниз', (tester) async {
    final repo = _ServerRepo();
    await open(tester, repo);
    expect(find.text('Пока пусто'), findsOneWidget);

    repo.mine = [order('Solaris')];
    await pullDown(tester);

    expect(card('Solaris'), findsOneWidget);
  });

  testWidgets('перечитывание не прячет список за спиннером', (tester) async {
    final repo = _ServerRepo()..mine = [order('Solaris')];
    await open(tester, repo);

    repo.mine = [order('Creta')];
    await tester.fling(find.byType(ListView), const Offset(0, 500), 1000);
    // запрос ушёл, ответ ещё не разобран — карточка на месте
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();
    expect(card('Creta'), findsOneWidget);
  });

  testWidgets('сбой при потягивании — список на месте и снекбар', (
    tester,
  ) async {
    final repo = _ServerRepo()..mine = [order('Solaris')];
    await open(tester, repo);

    repo.fail = true;
    await pullDown(tester);

    expect(card('Solaris'), findsOneWidget);
    expect(find.text('Не удалось загрузить заказы'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('сбой опроса молчит и список не стирает', (tester) async {
    final repo = _ServerRepo()..mine = [order('Solaris')];
    await open(tester, repo);

    repo.fail = true;
    await tester.pump(AutoRefresh.pollInterval);
    await tester.pumpAndSettle();

    expect(card('Solaris'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('опрос — страховка раз в pollInterval; после закрытия — тишина', (
    tester,
  ) async {
    final repo = _ServerRepo()..mine = [order('Solaris')];
    await open(tester, repo);

    repo.mine = [order('Creta')];
    // основной сигнал — уведомление; таймер редкий (ревью №42): список
    // целиком за 30 с не перечитываем
    final opened = repo.fetches;
    const early = Duration(seconds: 30);
    await tester.pump(early);
    expect(repo.fetches, opened);
    await tester.pump(AutoRefresh.pollInterval - early);
    await tester.pump();
    expect(card('Creta'), findsOneWidget);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    final fetches = repo.fetches;
    await tester.pump(AutoRefresh.pollInterval * 3);
    expect(repo.fetches, fetches);
  });

  testWidgets('возврат на экран перечитывает один раз', (tester) async {
    final repo = _ServerRepo()..mine = [order('Solaris')];
    await open(tester, repo);

    navigator.currentState!.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('чат'))),
    );
    await tester.pumpAndSettle();
    // пока сверху другой экран, опрос не ходит
    final fetches = repo.fetches;
    await tester.pump(AutoRefresh.pollInterval);
    expect(repo.fetches, fetches);

    repo.mine = [order('Creta')];
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(repo.fetches, fetches + 1);
    expect(card('Creta'), findsOneWidget);
  });

  testWidgets('«Взятые заказы» исполнителя — тоже сами', (tester) async {
    final repo = _ServerRepo()..assigned = [order('Solaris')];
    await open(tester, repo, asExecutor: true);

    repo.assigned = [order('Solaris'), order('Creta', id: 3002)];
    await tester.pump(AutoRefresh.pollInterval);
    await tester.pump();

    expect(card('Solaris'), findsOneWidget);
    expect(card('Creta'), findsOneWidget);
  });
}
