import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/models/code_channel.dart';
import 'package:auto_podbor_mobile/screens/phone_login_screen.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Запрос кода без сети: отдаёт заданный ответ или бросает заданную ошибку.
class _FakeAuth extends AuthService {
  _FakeAuth({this.sent = const PhoneCodeSent(), this.error});

  final PhoneCodeSent sent;
  Object? error;
  int requests = 0;

  @override
  Future<PhoneCodeSent> requestPhoneCode(String phone) async {
    requests++;
    final e = error;
    if (e != null) throw e;
    return sent;
  }
}

void main() {
  Future<void> pump(WidgetTester tester, AuthService auth) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PhoneLoginScreen(auth: auth, onLoggedIn: () {}),
      ),
    );
    await tester.enterText(find.byType(TextField).first, '9001234567');
    await tester.pump();
  }

  TextButton ghost(WidgetTester tester, String label) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, label));

  ElevatedButton primary(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  test('канал, retry_after и отсчёт', () {
    expect(codeChannelFromApi('telegram_call'), CodeChannel.telegramCall);
    expect(codeChannelFromApi('call_telegram'), CodeChannel.callTelegram);
    expect(codeChannelFromApi('pigeon'), isNull);
    expect(
      codeChannelHint(CodeChannel.telegramCall),
      'Код придёт в Telegram. Если Telegram нет — позвоним и продиктуем',
    );
    expect(
      codeChannelHint(CodeChannel.callTelegram),
      startsWith('Мы позвоним'),
    );
    // до запроса — как на проде: сначала Telegram
    expect(codeChannelHint(null), codeChannelHint(CodeChannel.telegramCall));

    expect(
      ApiException(429, '{"message":"x","retry_after":42}').retryAfter,
      42,
    );
    expect(ApiException(429, 'Too Many Attempts.').retryAfter, isNull);

    expect(formatCountdown(const Duration(seconds: 107)), '1:47');
    expect(formatCountdown(const Duration(seconds: 5)), '0:05');
  });

  test('долгая пауза — время, а не «1366:04» (QA №31)', () {
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day, 9, 0, 30);

    expect(cooldownWhen(const Duration(minutes: 10), now: now), 'через 10:00');
    // минута — вверх: 10:31:30 → 10:32
    expect(
      cooldownWhen(const Duration(minutes: 91), now: now),
      'сегодня в 10:32',
    );
    expect(
      cooldownWhen(const Duration(minutes: 89, seconds: 30), now: now),
      'сегодня в 10:30',
    );
    expect(
      cooldownWhen(const Duration(hours: 22, minutes: 46), now: now),
      'завтра в 07:47',
    );
  });

  testWidgets('код ушёл: подсказка по каналу и пауза до повторного запроса', (
    tester,
  ) async {
    final auth = _FakeAuth(
      sent: const PhoneCodeSent(
        resendIn: 120,
        channel: CodeChannel.callTelegram,
      ),
    );
    await pump(tester, auth);

    expect(find.text('Получить код'), findsOneWidget);
    await tester.tap(find.text('Получить код'));
    await tester.pump();

    expect(
      find.text(
        'Отправили код на +7 900 123 45 67. Мы позвоним и продиктуем код. Если не дозвонимся — пришлём в Telegram',
      ),
      findsOneWidget,
    );
    expect(ghost(tester, 'Запросить код снова через 2:00').onPressed, isNull);

    await tester.pump(const Duration(seconds: 61));
    expect(find.text('Запросить код снова через 0:59'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    expect(ghost(tester, 'Запросить код снова').onPressed, isNotNull);

    await tester.tap(find.text('Запросить код снова'));
    await tester.pump();
    expect(auth.requests, 2);

    // таймер новой паузы не должен пережить экран
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('429 с retry_after: русская причина и отсчёт на кнопке', (
    tester,
  ) async {
    final auth = _FakeAuth(
      error: ApiException(
        429,
        '{"message":"Новый код можно запросить через 42 с.","retry_after":42}',
      ),
    );
    await pump(tester, auth);

    await tester.tap(find.text('Получить код'));
    await tester.pump();

    expect(find.text('Новый код можно запросить через 42 с.'), findsOneWidget);
    expect(find.text('Получить код через 0:42'), findsOneWidget);
    expect(primary(tester).onPressed, isNull);

    // другой номер паузы не наследует: лимит на сервере — по номеру
    await tester.enterText(find.byType(TextField).first, '9007654321');
    await tester.pump();
    expect(find.text('Получить код'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('суточный лимит: на кнопке время, а не отсчёт', (tester) async {
    final auth = _FakeAuth(
      error: ApiException(
        429,
        '{"message":"Слишком много запросов кода на этот номер.","retry_after":82000}',
      ),
    );
    await pump(tester, auth);

    await tester.tap(find.text('Получить код'));
    await tester.pump();

    expect(
      find.textContaining(
        RegExp(r'^Получить код (сегодня|завтра) в \d\d:\d\d$'),
      ),
      findsOneWidget,
    );
    expect(primary(tester).onPressed, isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('стандартный 429 без причины — по-русски', (tester) async {
    final auth = _FakeAuth(
      error: ApiException(429, '{"message":"Too Many Attempts."}'),
    );
    await pump(tester, auth);

    await tester.tap(find.text('Получить код'));
    await tester.pump();

    expect(find.textContaining('Too Many'), findsNothing);
    expect(
      find.text('Слишком много запросов. Подождите немного и повторите'),
      findsOneWidget,
    );
  });
}
