import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';

/// Выход без сети (ревью №30): сессия на телефоне стирается сразу, а токен
/// остаётся в долге, пока сервер его не отзовёт, — иначе на телефон шли бы
/// пуши вышедшего аккаунта.
void main() {
  const storage = FlutterSecureStorage();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  AuthService signedIn(String token) => AuthService()
    ..debugSetToken(token)
    ..debugSetUser(const CurrentUser(id: 1, name: 'Андрей', email: 'a@b.c'));

  Future<List<String>> pending() async {
    final raw = await storage.read(key: 'pending_logouts');
    return raw == null ? [] : raw.substring(1, raw.length - 1).split(',');
  }

  /// Сервер: что ответить на /logout и с какими токенами его звали.
  ({MockClient client, List<String> logouts}) server(int Function() status) {
    final logouts = <String>[];
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/logout')) {
        logouts.add(r.headers['Authorization']!);
        return http.Response('', status());
      }
      return http.Response('{}', 401);
    });
    return (client: client, logouts: logouts);
  }

  Future<void> run(MockClient client, Future<void> Function() body) =>
      http.runWithClient(body, () => client);

  MockClient offline() =>
      MockClient((_) => throw http.ClientException('no network'));

  test(
    'без сети: выход сразу, токен в долге, отзыв при следующем запуске',
    () async {
      final auth = signedIn('t1');
      await run(offline(), () async {
        await auth.logout();
        expect(auth.isAuthenticated, isFalse, reason: 'выход не ждёт сети');
        await auth.flushPendingLogouts();
      });
      expect(await pending(), ['"t1"']);

      final s = server(() => 204);
      final next = AuthService();
      await run(s.client, () async {
        await next.restore();
        await next.flushPendingLogouts();
      });

      expect(s.logouts, ['Bearer t1']);
      expect(await pending(), isEmpty);
    },
  );

  test('с сетью долг снимается сразу', () async {
    final s = server(() => 204);
    final auth = signedIn('t1');
    await run(s.client, () async {
      await auth.logout();
      await auth.flushPendingLogouts();
    });

    expect(s.logouts, ['Bearer t1']);
    expect(await pending(), isEmpty);
  });

  test('401 — сессии на сервере уже нет, долг тоже снят', () async {
    final s = server(() => 401);
    final auth = signedIn('t1');
    await run(s.client, () async {
      await auth.logout();
      await auth.flushPendingLogouts();
    });

    expect(await pending(), isEmpty);
  });

  test('сервер лежит — долг остаётся, срабатывает запасной путь', () async {
    var fallbacks = 0;
    final auth = signedIn('t1')..addLogoutFallback(() async => fallbacks++);
    await run(server(() => 503).client, () async {
      await auth.logout();
      await auth.flushPendingLogouts();
    });

    expect(await pending(), ['"t1"']);
    expect(fallbacks, 1);

    // с сетью запасной путь не нужен
    final ok = signedIn('t2')..addLogoutFallback(() async => fallbacks++);
    await run(server(() => 204).client, () async {
      await ok.logout();
      await ok.flushPendingLogouts();
    });
    expect(fallbacks, 1);
    expect(await pending(), isEmpty, reason: 'отозваны оба: t1 и t2');
  });

  test('вошли снова — пуш-токен новой сессии не гасим', () async {
    var fallbacks = 0;
    final auth = signedIn('t1')..addLogoutFallback(() async => fallbacks++);
    await run(offline(), () async {
      await auth.logout();
      await auth.flushPendingLogouts();
    });
    expect(fallbacks, 1);

    auth.debugSetToken('t2'); // вошёл другой
    await run(offline(), auth.flushPendingLogouts);
    expect(fallbacks, 1);
  });

  test('два выхода без сети — оба токена отзываются потом', () async {
    await run(offline(), () async {
      final a = signedIn('t1');
      await a.logout();
      await a.flushPendingLogouts();
      final b = signedIn('t2');
      await b.logout();
      await b.flushPendingLogouts();
    });
    expect(await pending(), ['"t1"', '"t2"']);

    final s = server(() => 204);
    await run(s.client, AuthService().flushPendingLogouts);

    expect(s.logouts, ['Bearer t1', 'Bearer t2']);
    expect(await pending(), isEmpty);
  });
}
