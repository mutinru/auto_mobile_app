import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/session_repository.dart';
import 'package:auto_podbor_mobile/models/session.dart';
import 'package:auto_podbor_mobile/screens/sessions_screen.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

class _FakeSessions implements SessionRepository {
  _FakeSessions(this.sessions);

  List<Session> sessions;
  bool failNext = false;
  final revoked = <int>[];
  var revokedOthers = 0;

  @override
  Future<List<Session>> fetchSessions() async {
    if (failNext) {
      failNext = false;
      throw ApiException(500, '{"message":"Server Error"}');
    }
    return sessions;
  }

  @override
  Future<void> revoke(int sessionId) async {
    revoked.add(sessionId);
    sessions = sessions.where((s) => s.id != sessionId).toList();
  }

  @override
  Future<void> revokeOthers() async {
    revokedOthers++;
    sessions = sessions.where((s) => s.current).toList();
  }
}

/// «Активные устройства» (бекенд, ревью №24) и имя устройства при входе.
void main() {
  final sessions = [
    Session(
      id: 2,
      deviceName: 'iPhone 15',
      platform: 'ios',
      lastUsedAt: DateTime(2026, 11, 1, 10),
    ),
    const Session(
      id: 1,
      deviceName: 'Google Pixel 8',
      platform: 'android',
      current: true,
    ),
    const Session(id: 3),
  ];

  Future<_FakeSessions> pump(WidgetTester tester, _FakeSessions repo) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SessionsScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  test('разбор сессии и подпись без имени', () {
    final s = Session.fromJson({
      'id': 5,
      'device_name': null,
      'platform': 'android',
      'current': false,
      'last_used_at': '2026-11-10T09:00:00+00:00',
      'expires_at': '2027-02-08T09:00:00+00:00',
    });
    expect(s.title, 'Устройство Android');
    expect(s.lastUsedAt, DateTime.utc(2026, 11, 10, 9).toLocal());
    expect(const Session(id: 1).title, 'Устройство');
  });

  testWidgets('это устройство первым и без кнопки, выход на другом', (
    tester,
  ) async {
    final repo = await pump(tester, _FakeSessions(sessions));

    expect(find.text('Это устройство'), findsOneWidget);
    // первым — текущее, хотя сервер прислал его вторым
    final titles = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((t) => t == 'Google Pixel 8' || t == 'iPhone 15')
        .toList();
    expect(titles, ['Google Pixel 8', 'iPhone 15']);
    expect(find.text('Выйти'), findsNWidgets(2));

    await tester.tap(find.text('Выйти').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти').last); // в шторке
    await tester.pumpAndSettle();
    expect(repo.revoked, [2]);
    expect(find.text('iPhone 15'), findsNothing);
  });

  testWidgets('выйти на всех других', (tester) async {
    final repo = await pump(tester, _FakeSessions(sessions));

    await tester.tap(find.text('Выйти на всех других'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти').last);
    await tester.pumpAndSettle();

    expect(repo.revokedOthers, 1);
    expect(find.text('Выйти на всех других'), findsNothing);
  });

  testWidgets('ошибка загрузки — «Повторить»', (tester) async {
    final repo = _FakeSessions(sessions)..failNext = true;
    await pump(tester, repo);

    expect(find.text('Не удалось загрузить устройства'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Google Pixel 8'), findsOneWidget);
  });

  test('при входе уходит имя устройства, без него — без поля', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final sent = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/phone/verify')) {
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{"token":"t"}', 200);
      }
      // профиль после входа — тесту не нужен
      return http.Response('{}', 404);
    });
    addTearDown(() => AuthService.deviceNameSource = () async => null);

    AuthService.deviceNameSource = () async => 'Google Pixel 8';
    await http.runWithClient(
      () => AuthService().verifyPhoneCode('+79001234567', '1234'),
      () => client,
    );
    AuthService.deviceNameSource = () async => null;
    await http.runWithClient(
      () => AuthService().verifyPhoneCode('+79001234567', '1234'),
      () => client,
    );

    expect(sent[0]['device_name'], 'Google Pixel 8');
    expect(sent[1].containsKey('device_name'), isFalse);
    // согласие с документами — обязательное поле входа
    expect(sent.map((b) => b['accept_legal']), everyElement(isTrue));
  });
}
