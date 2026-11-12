import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auto_podbor_mobile/data/api_client.dart';
import 'package:auto_podbor_mobile/data/app_build.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/http_transport.dart';
import 'package:auto_podbor_mobile/models/client_config.dart';
import 'package:auto_podbor_mobile/screens/update_required_screen.dart';
import 'package:auto_podbor_mobile/state/app_update.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Принудительное обновление (ревью №11): номер сборки в каждом запросе,
/// min_build из /config и 426 включают экран обновления.
void main() {
  const build87 = AppBuildInfo(number: 87, packageName: 'com.bitnebit.app');

  setUp(() {
    AppUpdate.debugReset();
    AppBuild.debugInfo = build87;
  });
  tearDown(() {
    AppUpdate.debugReset();
    AppBuild.debugInfo = null;
  });

  http.Response config(int minBuild) => http.Response(
    jsonEncode({
      'data': {'min_build': minBuild},
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<T> withServer<T>(
    Future<http.Response> Function(http.Request) handler,
    Future<T> Function() body,
  ) => http.runWithClient(body, () => MockClient(handler));

  test('ClientConfig разбирает min_build, без поля — 0', () {
    expect(ClientConfig.fromJson({'min_build': 120}).minBuild, 120);
    expect(ClientConfig.fromJson({}).minBuild, 0);
  });

  test(
    'каждый запрос несёт номер сборки, неизвестный — без заголовка',
    () async {
      final seen = <String?>[];
      Future<http.Response> handler(http.Request r) async {
        seen.add(r.headers[HttpTransport.buildHeader]);
        return http.Response('{}', 200);
      }

      await withServer(
        handler,
        () => HttpTransport.request('GET', Uri.parse('http://x/api/ping')),
      );
      AppBuild.debugInfo = null;
      await withServer(
        handler,
        () => HttpTransport.request('GET', Uri.parse('http://x/api/ping')),
      );

      expect(seen, ['87', null]);
    },
  );

  test('ответ 426 включает экран обновления', () async {
    await withServer(
      (_) async => http.Response('{"min_build":120}', 426),
      () => HttpTransport.request('GET', Uri.parse('http://x/api/me')),
    );

    expect(AppUpdate.required.value, isTrue);
  });

  group('проверка при запуске', () {
    Future<void> check(Future<http.Response> Function(http.Request) h) =>
        withServer(h, () => AppUpdate.checkOnStart(ApiClient(AuthService())));

    test('min_build выше своей сборки — обновиться', () async {
      await check((_) async => config(88));
      expect(AppUpdate.required.value, isTrue);
    });

    test('своя сборка не старее — работаем', () async {
      await check((_) async => config(87));
      expect(AppUpdate.required.value, isFalse);
    });

    test('нет сети — не блокируем', () async {
      await check((_) async => throw const SocketLikeException());
      expect(AppUpdate.required.value, isFalse);
    });

    test('номер своей сборки неизвестен — не блокируем', () async {
      AppBuild.debugInfo = null;
      await check((_) async => config(1000));
      expect(AppUpdate.required.value, isFalse);
    });
  });

  group('магазин для обновления', () {
    test('по установщику', () {
      expect(AppStore.forInstaller('com.android.vending', android: true), [
        AppStore.googlePlay,
      ]);
      expect(AppStore.forInstaller('ru.vk.store', android: true), [
        AppStore.ruStore,
      ]);
      expect(AppStore.forInstaller(null, android: true), [
        AppStore.googlePlay,
        AppStore.ruStore,
      ]);
      expect(AppStore.forInstaller('com.android.vending', android: false), []);
    });

    test('ссылки на страницу приложения', () {
      expect(
        AppStore.googlePlay.pageFor('com.bitnebit.app').toString(),
        'https://play.google.com/store/apps/details?id=com.bitnebit.app',
      );
      expect(
        AppStore.ruStore.pageFor('com.bitnebit.app').toString(),
        'https://www.rustore.ru/catalog/app/com.bitnebit.app',
      );
    });
  });

  Widget app({required Widget home}) => MaterialApp(
    theme: AppTheme.light,
    builder: (_, child) => UpdateGate(child: child!),
    home: home,
  );

  testWidgets('экран обновления встаёт поверх приложения', (tester) async {
    await tester.pumpWidget(app(home: const Text('Мои заказы')));
    expect(find.text('Мои заказы'), findsOneWidget);

    AppUpdate.markRequired();
    await tester.pump();

    expect(find.text('Мои заказы'), findsNothing);
    expect(find.text('Обновите приложение'), findsOneWidget);
    expect(find.text('Написать в поддержку'), findsOneWidget);
  });

  testWidgets('поставили из RuStore — одна кнопка «Обновить»', (tester) async {
    await tester.pumpWidget(
      app(
        home: const UpdateRequiredScreen(
          android: true,
          appBuild: AppBuildInfo(
            number: 87,
            packageName: 'com.bitnebit.app',
            installerStore: 'ru.vk.store',
          ),
        ),
      ),
    );

    expect(find.text('Обновить'), findsOneWidget);
    expect(find.textContaining('Google Play'), findsNothing);
  });

  testWidgets('APK вручную — обе кнопки', (tester) async {
    await tester.pumpWidget(
      app(
        home: const UpdateRequiredScreen(android: true, appBuild: build87),
      ),
    );

    expect(find.text('Обновить в Google Play'), findsOneWidget);
    expect(find.text('Обновить в RuStore'), findsOneWidget);
  });
}

class SocketLikeException implements Exception {
  const SocketLikeException();
}
