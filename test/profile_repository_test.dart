import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/profile_repository.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/models/notification_category.dart';
import 'package:auto_podbor_mobile/models/order_alerts.dart';
import 'package:auto_podbor_mobile/models/payout.dart';

/// Профиль отдельно от сессии (ревью №40): правки идут через ApiClient — тот
/// же Bearer, тот же 401 и ошибки, — а профиль из ответа ложится в сессию.
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({'auth_token': 't'}));

  AuthService signedIn() => AuthService()
    ..debugSetToken('t')
    ..debugSetUser(const CurrentUser(id: 1, name: 'Андрей', email: 'a@b.c'));

  /// Профиль в форме GET /me с новым именем.
  http.Response profile(String name) => http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'data': {'id': 1, 'name': name, 'email': 'a@b.c'},
      }),
    ),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  /// Выполнить [run] с сервером, который отвечает [answer] и запоминает запросы.
  Future<List<http.BaseRequest>> serve(
    http.Response Function(http.Request) answer,
    Future<void> Function() run,
  ) async {
    final sent = <http.BaseRequest>[];
    await http.runWithClient(
      run,
      () => MockClient((request) async {
        sent.add(request);
        return answer(request);
      }),
    );
    return sent;
  }

  test('каждая правка — свой метод и путь, с Bearer; профиль в сессии', () async {
    final photo = File('${Directory.systemTemp.createTempSync().path}/a.jpg')
      ..writeAsBytesSync([0xFF, 0xD8]);
    addTearDown(() => photo.parent.deleteSync(recursive: true));
    final cases = <String, Future<void> Function(ProfileRepository)>{
      'PATCH /me': (p) => p.updateName('Андрей С.'),
      'POST /me/avatar': (p) => p.uploadAvatar(photo.path),
      'DELETE /me/avatar': (p) => p.deleteAvatar(),
      'POST /me/phone/verify': (p) =>
          p.confirmPhoneChange('+79000000005', '1234'),
      'PATCH /me/payout': (p) =>
          p.updatePayout(const Payout(card: '2200000000000009')),
      'PATCH /me/notifications': (p) =>
          p.updatePushMuted({NotificationCategory.values.first}),
      'PUT /me/order-alerts': (p) =>
          p.updateOrderAlerts(const OrderAlerts(cities: {'Казань'})),
    };

    for (final MapEntry(key: route, value: call) in cases.entries) {
      final auth = signedIn();
      var notified = 0;
      auth.addListener(() => notified++);

      final sent = await serve(
        (_) => profile('Новое имя'),
        () => call(ProfileRepository(auth)),
      );

      final request = sent.single;
      expect(
        '${request.method} ${request.url.path.replaceFirst(RegExp('^.*/api'), '')}',
        route,
      );
      expect(request.headers['Authorization'], 'Bearer t', reason: route);
      expect(auth.user?.name, 'Новое имя', reason: route);
      expect(notified, 1, reason: route);
    }
  });

  test('тела запросов — как прежде у AuthService', () async {
    final auth = signedIn();
    final repo = ProfileRepository(auth);
    final bodies = <String, Object?>{};
    await serve(
      (request) {
        bodies[request.url.path.split('/api').last] = jsonDecode(request.body);
        return profile('Андрей');
      },
      () async {
        await repo.updateName('Андрей С.');
        await repo.updatePushMuted({NotificationCategory.values.first});
        await repo.updateOrderAlerts(const OrderAlerts(cities: {'Казань'}));
      },
    );
    expect(bodies['/me'], {'name': 'Андрей С.'});
    expect(bodies['/me/notifications'], {
      'push_muted': [NotificationCategory.values.first.apiValue],
    });
    expect((bodies['/me/order-alerts'] as Map)['cities'], ['Казань']);
  });

  test('код на новый номер — PhoneCodeSent', () async {
    final sent = await serve(
      (_) => http.Response('{"resend_in":60,"channel":"telegram_call"}', 200),
      () async {
        final code = await ProfileRepository(
          signedIn(),
        ).requestPhoneChange('+79000000005');
        expect(code.resendIn, 60);
      },
    );
    expect(sent.single.url.path, endsWith('/me/phone/request'));
  });

  test('422 — ошибки по полям, профиль прежний', () async {
    final auth = signedIn();
    await expectLater(
      serve(
        (_) => http.Response.bytes(
          utf8.encode(
            '{"message":"Проверьте","errors":{"payout_card":["Проверьте номер карты."]}}',
          ),
          422,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
        () => ProfileRepository(auth).updatePayout(const Payout(card: '1')),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.fieldErrors,
          'fieldErrors',
          {'payout_card': 'Проверьте номер карты.'},
        ),
      ),
    );
    expect(auth.user?.name, 'Андрей');
  });

  test('401 — сессия протухла, корень уведёт на вход', () async {
    final auth = signedIn();
    await expectLater(
      serve(
        (_) => http.Response('{}', 401),
        () => ProfileRepository(auth).updateName('Андрей С.'),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(auth.isAuthenticated, isFalse);
    expect(auth.sessionExpired, isTrue);
  });

  test('ответ, пришедший после выхода, профиль не возвращает', () {
    final auth = AuthService();
    auth.applyUser(const CurrentUser(id: 1, name: 'Андрей', email: 'a@b.c'));
    expect(auth.user, isNull);
  });
}
