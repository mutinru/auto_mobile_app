import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/profile_repository.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';

/// Удаление аккаунта (DELETE /me): 204 стирает сессию, отказ сервера —
/// оставляет вошедшим с текстом причины, 401 — протухшая сессия.
void main() {
  Future<AuthService> signedIn() async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 't'});
    // профиль уже загружен, как в приложении: ApiClient не ходит за /me
    return AuthService()
      ..debugSetToken('t')
      ..debugSetUser(const CurrentUser(id: 1, name: 'Андрей', email: 'a@b.c'));
  }

  Future<String?> savedToken() =>
      const FlutterSecureStorage().read(key: 'auth_token');

  test('204 — сессия стёрта, токен с диска удалён', () async {
    final auth = await signedIn();
    late http.Request sent;

    await http.runWithClient(
      ProfileRepository(auth).deleteAccount,
      () => MockClient((request) async {
        sent = request;
        return http.Response('', 204);
      }),
    );

    expect(sent.method, 'DELETE');
    expect(sent.url.path, endsWith('/me'));
    expect(sent.headers['Authorization'], 'Bearer t');
    expect(auth.isAuthenticated, isFalse);
    expect(auth.sessionExpired, isFalse);
    expect(await savedToken(), isNull);
  });

  test('422 — остаёмся вошедшими, причина из ответа сервера', () async {
    final auth = await signedIn();

    await expectLater(
      http.runWithClient(
        ProfileRepository(auth).deleteAccount,
        () => MockClient(
          (_) async => http.Response(
            '{"message":"Удалить аккаунт пока нельзя — дождитесь выплаты за выполненные заказы.","orders":[]}',
            422,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 422)
            .having(
              (e) => e.userMessage,
              'userMessage',
              'Удалить аккаунт пока нельзя — дождитесь выплаты за выполненные заказы.',
            ),
      ),
    );

    expect(auth.isAuthenticated, isTrue);
    expect(await savedToken(), 't');
  });

  test('401 — сессия протухла, корень уведёт на вход', () async {
    final auth = await signedIn();

    await expectLater(
      http.runWithClient(
        ProfileRepository(auth).deleteAccount,
        () => MockClient((_) async => http.Response('{}', 401)),
      ),
      throwsA(isA<ApiException>()),
    );

    expect(auth.isAuthenticated, isFalse);
    expect(auth.sessionExpired, isTrue);
  });
}
