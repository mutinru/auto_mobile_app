import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/state/order_session.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';

/// «Мои заказы» отвечают, когда тест отпустит [hold].
class _Slow extends MockOrderRepository {
  Completer<void>? hold;

  @override
  Future<List<Order>> fetchMyOrders() async {
    await hold?.future;
    return super.fetchMyOrders();
  }
}

/// Один стор заказов на сессию входа (ревью №41): действие на экране заказа
/// видно во всех списках, а выход списки прошлого пользователя сбрасывает.
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  AuthService signedIn() => AuthService()
    ..debugSetToken('t1')
    ..debugSetUser(const CurrentUser(id: 1, name: 'Андрей', email: 'a@b.c'));

  OrderSession session(AuthService auth, [MockOrderRepository? repo]) =>
      OrderSession(
        auth,
        () => OrderStore(
          repo ?? MockOrderRepository(),
          catalog: MockCarCatalogRepository(),
          cities: MockCityRepository(),
        ),
      );

  /// Выход без сети: /logout уходит в долг, сессия стирается сразу.
  Future<void> logout(AuthService auth) => http.runWithClient(
    auth.logout,
    () => MockClient((_) => throw http.ClientException('no network')),
  );

  test('один стор на сессию: все экраны получают один объект', () {
    final orders = session(signedIn());
    expect(identical(orders.store, orders.store), isTrue);
  });

  test('выход сбрасывает стор: следующий вход — со своими списками', () async {
    final auth = signedIn();
    final orders = session(auth);
    final before = orders.store;
    await before.loadMyOrders();
    expect(before.myOrders, isNotEmpty);

    await logout(auth);

    final after = orders.store;
    expect(identical(before, after), isFalse);
    expect(after.myOrders, isEmpty);
  });

  test('истёкшая сессия (401) — тоже новый стор', () {
    final auth = signedIn();
    final orders = session(auth);
    final before = orders.store;

    auth.expireSession();

    expect(identical(before, orders.store), isFalse);
  });

  test('ответ, пришедший после выхода, не роняет освобождённый стор', () async {
    final auth = signedIn();
    final repo = _Slow()..hold = Completer<void>();
    final orders = session(auth, repo);
    final store = orders.store;
    var notified = 0;
    store.addListener(() => notified++);

    final load = store.loadMyOrders();
    // начало загрузки сообщается микрозадачей — дать ему дойти
    await Future<void>.delayed(Duration.zero);
    final seen = notified;
    expect(seen, 1);
    await logout(auth);
    repo.hold!.complete();
    await load;

    // ответ принят молча: уведомление после dispose — assert ChangeNotifier
    expect(notified, seen);
    store.replaceOrder((await MockOrderRepository().fetchMyOrders()).first);
    store.myFinished.replace((await repo.fetchMyOrders()).first);
  });
}
