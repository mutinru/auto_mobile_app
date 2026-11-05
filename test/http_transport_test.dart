import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auto_podbor_mobile/data/api_client.dart';
import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/http_transport.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/widgets/api_error.dart';

/// Один транспорт с таймаутами (бэклог №35): ни один запрос не висит
/// бесконечно, и мимо транспорта в сеть никто не ходит.
void main() {
  AuthService signedIn() => AuthService()
    ..debugSetToken('t')
    ..debugSetUser(const CurrentUser(id: 1, name: 'Андрей', email: 'a@b.c'));

  /// Сервер, который не отвечает никогда.
  MockClient silent() => MockClient((_) => Completer<http.Response>().future);

  /// Запустить [call] с подменённой сетью и запомнить, чем он кончился.
  Object? Function() start(Future<Object?> Function() call, MockClient client) {
    Object? outcome;
    http.runWithClient(() {
      call().then((v) => outcome = v ?? 'ok', onError: (e) => outcome = e);
    }, () => client);
    return () => outcome;
  }

  testWidgets('обычный запрос — «Нет связи» через 30 с, не раньше', (
    tester,
  ) async {
    final outcome = start(() => ApiClient(signedIn()).get('/orders'), silent());

    await tester.pump(
      HttpTransport.requestTimeout - const Duration(seconds: 1),
    );
    expect(outcome(), isNull);

    await tester.pump(const Duration(seconds: 2));
    expect(outcome(), isA<TimeoutException>());
    expect(apiErrorText(outcome()!), networkErrorText);
  });

  testWidgets('загрузка файла ждёт дольше — 3 минуты', (tester) async {
    final outcome = start(
      () => ApiClient(signedIn()).multipart('/photos', fields: {'a': 'b'}),
      silent(),
    );

    await tester.pump(const Duration(seconds: 31));
    expect(outcome(), isNull, reason: 'фото на медленной сети идёт минуты');

    await tester.pump(HttpTransport.uploadTimeout);
    expect(outcome(), isA<TimeoutException>());
  });

  testWidgets('multipart: JSON, 422 по полям, 401 стирает сессию', (
    tester,
  ) async {
    http.BaseRequest? seen;
    Future<Object?> upload(AuthService auth, int status, String body) {
      final client = MockClient((request) async {
        seen = request;
        return http.Response(
          body,
          status,
          headers: {'content-type': 'application/json'},
        );
      });
      return http.runWithClient(
        () => ApiClient(auth).multipart('/photos', fields: {'a': 'b'}),
        () => client,
      );
    }

    final auth = signedIn();
    expect(await upload(auth, 200, '{"data":{"id":5}}'), {
      'data': {'id': 5},
    });
    expect(seen!.headers['Authorization'], 'Bearer t');
    expect(seen!.headers['content-type'], startsWith('multipart/form-data'));

    Object? invalid;
    try {
      await upload(
        auth,
        422,
        '{"message":"x","errors":{"photo":["Слишком большое фото"]}}',
      );
    } catch (e) {
      invalid = e;
    }
    expect(
      (invalid! as ApiException).fieldErrors['photo'],
      'Слишком большое фото',
    );

    try {
      await upload(auth, 401, '{}');
    } on ApiException {
      // 401 — ожидаемо
    }
    expect(auth.isAuthenticated, isFalse);
  });

  test('в сеть ходит только HttpTransport', () {
    final direct = RegExp(
      r'http\.(get|post|put|patch|delete|head|read|readBytes)\(|'
      r'http\.Client\(|\.send\(\)',
    );
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith('http_transport.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        if (direct.hasMatch(line)) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'запрос мимо таймаута транспорта');
  });
}
