import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auto_podbor_mobile/data/api_client.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';

/// Старт с сохранённым токеном: сессию стирает только 401, а нет сети,
/// 5xx и таймаут оставляют пользователя вошедшим.
void main() {
  // кириллица в теле — нужен charset, иначе http.Response кодирует latin1
  http.Response me() => http.Response(
        '{"data":{"id":7,"name":"Максим К.","email":"m@example.com"}}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Future<AuthService> restoreWith(MockClient client) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 't'});
    final auth = AuthService();
    await http.runWithClient(auth.restore, () => client);
    return auth;
  }

  Future<String?> savedToken() => const FlutterSecureStorage().read(key: 'auth_token');

  test('нет сети — остаёмся вошедшими без профиля, токен на диске', () async {
    final auth = await restoreWith(MockClient((_) => throw http.ClientException('no network')));

    expect(auth.isRestoring, isFalse);
    expect(auth.isAuthenticated, isTrue);
    expect(auth.user, isNull);
    expect(await savedToken(), 't');
  });

  test('502 во время выкатки — тоже не повод разлогинивать', () async {
    final auth = await restoreWith(MockClient((_) async => http.Response('<html>502</html>', 502)));

    expect(auth.isAuthenticated, isTrue);
    expect(await savedToken(), 't');
  });

  // в testWidgets таймеры поддельные — 10 секунд проходят мгновенно
  testWidgets('сервер молчит — заставка не висит дольше таймаута', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 't'});
    final auth = AuthService();
    http.runWithClient(auth.restore, () => MockClient((_) => Completer<http.Response>().future));

    await tester.pump(AuthService.restoreTimeout + const Duration(seconds: 1));
    expect(auth.isRestoring, isFalse);
    expect(auth.isAuthenticated, isTrue);
  });

  test('401 — токен отозван: гость, диск чист, без «Сессия истекла»', () async {
    final auth = await restoreWith(MockClient((_) async => http.Response('{"message":"Unauthenticated."}', 401)));

    expect(auth.isAuthenticated, isFalse);
    expect(auth.sessionExpired, isFalse);
    expect(await savedToken(), isNull);
  });

  test('200 — профиль загружен', () async {
    final auth = await restoreWith(MockClient((_) async => me()));

    expect(auth.isAuthenticated, isTrue);
    expect(auth.user?.id, 7);
  });

  test('связь вернулась — ApiClient сначала догружает профиль, один раз', () async {
    final auth = await restoreWith(MockClient((_) => throw http.ClientException('no network')));
    final client = ApiClient(auth);
    final paths = <String>[];

    await http.runWithClient(
      () => Future.wait([client.get('/orders/mine'), client.get('/orders/assigned')]),
      () => MockClient((request) async {
        paths.add(request.url.path);
        return request.url.path.endsWith('/me')
            ? me()
            : http.Response('{"data":[]}', 200);
      }),
    );

    expect(paths.where((p) => p.endsWith('/me')), hasLength(1));
    expect(paths.first, endsWith('/me'));
    expect(auth.user?.id, 7);

    // профиль есть — /me больше не зовём
    paths.clear();
    await http.runWithClient(
      () => client.get('/orders/mine'),
      () => MockClient((request) async {
        paths.add(request.url.path);
        return http.Response('{"data":[]}', 200);
      }),
    );
    expect(paths, [endsWith('/orders/mine')]);
  });
}
