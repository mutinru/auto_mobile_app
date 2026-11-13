import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auto_podbor_mobile/data/api_client.dart';
import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/idempotency_keys.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/widgets/api_error.dart';

/// Ключ повтора мутаций (ревью №17): пока исход запроса неизвестен, та же
/// отправка уходит с тем же `Idempotency-Key`, и сервер не выполнит её
/// второй раз.
void main() {
  AuthService signedIn({int id = 1}) => AuthService()
    ..debugSetToken('t')
    ..debugSetUser(CurrentUser(id: id, name: 'Андрей', email: 'a@b.c'));

  String sig(String body, {int userId = 1, String path = '/orders'}) =>
      IdempotencyKeys.signature(
        userId: userId,
        method: 'POST',
        path: path,
        body: body,
      );

  group('IdempotencyKeys', () {
    test('тот же запрос — тот же ключ, пока исход неизвестен', () async {
      final keys = IdempotencyKeys.memory();
      final first = await keys.keyFor(sig('{"a":1}'));

      expect(await keys.keyFor(sig('{"a":1}')), first);
      expect(first, matches(RegExp(r'^[0-9a-f-]{36}$')));

      await keys.settle(sig('{"a":1}'));
      expect(await keys.keyFor(sig('{"a":1}')), isNot(first));
    });

    test('другое тело, путь или пользователь — другой ключ', () async {
      final keys = IdempotencyKeys.memory();
      final base = await keys.keyFor(sig('{"a":1}'));

      expect(await keys.keyFor(sig('{"a":2}')), isNot(base));
      expect(await keys.keyFor(sig('{"a":1}', path: '/x')), isNot(base));
      expect(await keys.keyFor(sig('{"a":1}', userId: 2)), isNot(base));
    });

    test('ключ живёт меньше суток сервера', () async {
      var now = DateTime(2026, 11, 13, 10);
      final keys = IdempotencyKeys.memory(now: () => now);
      final first = await keys.keyFor(sig('{}'));

      now = now.add(IdempotencyKeys.ttl - const Duration(minutes: 1));
      expect(await keys.keyFor(sig('{}')), first);

      now = now.add(const Duration(minutes: 2));
      expect(await keys.keyFor(sig('{}')), isNot(first));
      expect(IdempotencyKeys.ttl, lessThan(const Duration(hours: 24)));
    });

    test('старые вытесняются сверх лимита', () async {
      var now = DateTime(2026, 11, 13);
      final keys = IdempotencyKeys.memory(now: () => now);
      final oldest = await keys.keyFor(sig('0'));
      for (var i = 1; i <= IdempotencyKeys.maxEntries; i++) {
        now = now.add(const Duration(seconds: 1));
        await keys.keyFor(sig('$i'));
      }

      expect(keys.length, IdempotencyKeys.maxEntries);
      expect(await keys.keyFor(sig('0')), isNot(oldest));
    });

    test('переживает перезапуск, на диске нет тела запроса', () async {
      final dir = await Directory.systemTemp.createTemp('idem');
      addTearDown(() => dir.delete(recursive: true));
      final body = '{"payout_card":"4111111111111111"}';

      final first = await IdempotencyKeys.disk(root: dir).keyFor(sig(body));
      final restarted = IdempotencyKeys.disk(root: dir);

      expect(await restarted.keyFor(sig(body)), first);
      final stored = await File(
        '${dir.path}/idempotency_keys.json',
      ).readAsString();
      expect(stored, isNot(contains('4111')));

      await restarted.clear();
      expect(
        await IdempotencyKeys.disk(root: dir).keyFor(sig(body)),
        isNot(first),
      );
    });
  });

  group('ApiClient', () {
    late List<http.BaseRequest> sent;

    /// Сервер отвечает по очереди [responses]; null — обрыв связи.
    MockClient server(List<http.Response?> responses) {
      sent = [];
      var i = 0;
      return MockClient((request) async {
        sent.add(request);
        final r = responses[i++];
        if (r == null) throw http.ClientException('обрыв');
        return r;
      });
    }

    Future<T> run<T>(Future<T> Function() body, MockClient client) =>
        http.runWithClient(body, () => client);

    String? keyOf(int i) => sent[i].headers[IdempotencyKeys.header];

    test('мутации несут ключ, GET — нет', () async {
      final api = ApiClient(signedIn(), keys: IdempotencyKeys.memory());
      final client = server([
        http.Response('{}', 200),
        http.Response('{}', 201),
        http.Response('{}', 200),
        http.Response('{}', 200),
        http.Response('{}', 200),
      ]);

      await run(() async {
        await api.get('/orders');
        await api.post('/orders', {'a': 1});
        await api.patch('/me', {'name': 'А'});
        await api.put('/x');
        await api.delete('/photos/1');
      }, client);

      expect(keyOf(0), isNull);
      for (var i = 1; i < 5; i++) {
        expect(keyOf(i), isNotNull, reason: sent[i].method);
      }
    });

    test(
      'после обрыва повтор уходит с тем же ключом, после ответа — с новым',
      () async {
        final api = ApiClient(signedIn(), keys: IdempotencyKeys.memory());
        final client = server([
          null,
          http.Response('{}', 500),
          http.Response('{"id":7}', 201),
          http.Response('{"id":8}', 201),
        ]);

        await run(() async {
          await expectLater(
            api.post('/orders', {'brand': 'Kia'}),
            throwsA(isA<http.ClientException>()),
          );
          await expectLater(
            api.post('/orders', {'brand': 'Kia'}),
            throwsA(isA<ApiException>()),
          );
          expect(await api.post('/orders', {'brand': 'Kia'}), {'id': 7});
          // ответ пришёл — следующий такой же заказ уже новое действие
          expect(await api.post('/orders', {'brand': 'Kia'}), {'id': 8});
        }, client);

        expect(keyOf(1), keyOf(0));
        expect(keyOf(2), keyOf(0));
        expect(keyOf(3), isNot(keyOf(0)));
      },
    );

    test('отказ 422 — исход известен, ключ новый', () async {
      final api = ApiClient(signedIn(), keys: IdempotencyKeys.memory());
      final client = server([
        http.Response('{"message":"no"}', 422),
        http.Response('{}', 201),
      ]);

      await run(() async {
        await expectLater(
          api.post('/m', {'a': 1}),
          throwsA(isA<ApiException>()),
        );
        await api.post('/m', {'a': 1});
      }, client);

      expect(keyOf(1), isNot(keyOf(0)));
    });

    test('409 — ждёт и спрашивает тем же ключом', () async {
      final api = ApiClient(signedIn(), keys: IdempotencyKeys.memory());
      final busy = http.Response(
        '{"message":"busy","retry_after":0}',
        409,
        headers: {'retry-after': '0'},
      );
      final client = server([busy, busy, http.Response('{"id":1}', 201)]);

      final json = await run(() => api.post('/orders', {'a': 1}), client);

      expect(json, {'id': 1});
      expect(sent, hasLength(3));
      expect({keyOf(0), keyOf(1), keyOf(2)}, hasLength(1));
    });

    test(
      '409 дольше терпения — ошибка «ещё выполняется», ключ сохранён',
      () async {
        final keys = IdempotencyKeys.memory();
        final api = ApiClient(signedIn(), keys: keys);
        final busy = http.Response('{}', 409, headers: {'retry-after': '0'});
        final client = server([
          for (var i = 0; i < ApiClient.inProgressAttempts; i++) busy,
          http.Response('{}', 201),
        ]);

        await run(() async {
          Object? error;
          try {
            await api.post('/orders', {'a': 1});
          } catch (e) {
            error = e;
          }
          expect(error, isA<ApiException>());
          expect(apiErrorText(error!), inProgressText);
          await api.post('/orders', {'a': 1});
        }, client);

        expect(sent, hasLength(ApiClient.inProgressAttempts + 1));
        expect(keyOf(ApiClient.inProgressAttempts), keyOf(0));
      },
    );

    test('загрузка файла: тот же файл после обрыва — тот же ключ', () async {
      final api = ApiClient(signedIn(), keys: IdempotencyKeys.memory());
      final client = server([null, http.Response('{}', 200)]);
      http.MultipartFile file() =>
          http.MultipartFile.fromBytes('photo', [1, 2, 3], filename: 'p.jpg');

      await run(() async {
        await expectLater(
          api.multipart('/photos', fields: {'label': 'a'}, files: [file()]),
          throwsA(isA<http.ClientException>()),
        );
        await api.multipart('/photos', fields: {'label': 'a'}, files: [file()]);
      }, client);

      expect(keyOf(0), isNotNull);
      expect(keyOf(1), keyOf(0));
    });

    test('ключи разных пользователей не пересекаются', () async {
      final keys = IdempotencyKeys.memory();
      final client = server([null, null]);

      await run(() async {
        for (final id in [1, 2]) {
          await expectLater(
            ApiClient(signedIn(id: id), keys: keys).post('/m', {'a': 1}),
            throwsA(isA<http.ClientException>()),
          );
        }
      }, client);

      expect(keyOf(1), isNot(keyOf(0)));
    });
  });

  test('таймаут — ключ остаётся (исход неизвестен)', () async {
    final keys = IdempotencyKeys.memory();
    final signature = IdempotencyKeys.signature(
      userId: 1,
      method: 'POST',
      path: '/m',
      body: '{"a":1}',
    );
    final client = MockClient((_) async => throw TimeoutException('долго'));

    await http.runWithClient(() async {
      await expectLater(
        ApiClient(signedIn(), keys: keys).post('/m', {'a': 1}),
        throwsA(isA<TimeoutException>()),
      );
    }, () => client);

    expect(keys.length, 1);
    final key = await keys.keyFor(signature);
    expect(keys.length, 1, reason: 'тот же ключ, не новый: $key');
  });
}
