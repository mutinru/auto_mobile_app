import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/models/code_channel.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/change_phone_sheet.dart';
import 'package:auto_podbor_mobile/widgets/phone_input.dart';

void main() {
  /// Открывает лист с кнопки, чтобы проверить и закрытие после смены.
  Future<void> openSheet(
    WidgetTester tester, {
    Future<PhoneCodeSent> Function(String phone)? onRequest,
    Future<void> Function(String phone, String code)? onConfirm,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showChangePhoneSheet(
                context,
                currentPhone: '+79000000002',
                onRequest: onRequest ?? (_) async => const PhoneCodeSent(),
                onConfirm: onConfirm ?? (_, _) async {},
              ),
              child: const Text('открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();
  }

  ElevatedButton primary(WidgetTester tester) => tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  Future<void> enterPhone(WidgetTester tester, String digits) async {
    await tester.enterText(find.byType(TextField).first, digits);
    await tester.pump();
  }

  test('профиль читает phone, номер форматируется', () {
    final user = CurrentUser.fromJson({'id': 1, 'name': 'А', 'email': 'x', 'phone': '+79001234567'});
    expect(user.phone, '+79001234567');
    expect(CurrentUser.fromJson({'id': 1, 'name': 'А', 'email': 'x'}).phone, isNull);
    expect(formatPhone('+79001234567'), '+7 900 123 45 67');
    expect(formatPhone('+44123'), '+44123');
  });

  testWidgets('кнопка неактивна для неполного и текущего номера', (tester) async {
    await openSheet(tester);

    expect(find.textContaining('+7 900 000 00 02'), findsOneWidget);
    expect(primary(tester).onPressed, isNull);

    await enterPhone(tester, '900000000');
    expect(primary(tester).onPressed, isNull);

    await enterPhone(tester, '9000000002');
    expect(primary(tester).onPressed, isNull);

    await enterPhone(tester, '9000000021');
    expect(primary(tester).onPressed, isNotNull);
  });

  testWidgets('код ушёл — подсказка канала, dev_code подставлен, номер сменён', (tester) async {
    String? requested;
    String? confirmedPhone;
    String? confirmedCode;
    await openSheet(
      tester,
      onRequest: (phone) async {
        requested = phone;
        return const PhoneCodeSent(devCode: '4321', resendIn: 120, channel: CodeChannel.sms);
      },
      onConfirm: (phone, code) async {
        confirmedPhone = phone;
        confirmedCode = code;
      },
    );

    await enterPhone(tester, '9000000021');
    await tester.tap(find.text('Получить код'));
    await tester.pump();

    expect(requested, '900 000 00 21');
    expect(find.textContaining('Код придёт в SMS'), findsOneWidget);
    expect(find.text('Запросить код снова через 2:00'), findsOneWidget);
    expect(find.text('4321'), findsOneWidget);

    await tester.tap(find.text('Сменить номер'));
    await tester.pumpAndSettle();

    expect(confirmedPhone, '900 000 00 21');
    expect(confirmedCode, '4321');
    expect(find.text('Новый номер'), findsNothing);
    expect(find.text('Номер изменён'), findsOneWidget);
  });

  testWidgets('429 с retry_after запускает отсчёт', (tester) async {
    await openSheet(
      tester,
      onRequest: (_) async => throw ApiException(429, '{"message":"Новый код можно запросить через 90 с.","retry_after":90}'),
    );

    await enterPhone(tester, '9000000021');
    await tester.tap(find.text('Получить код'));
    await tester.pump();

    expect(find.text('Новый код можно запросить через 90 с.'), findsOneWidget);
    expect(find.text('Получить код через 1:30'), findsOneWidget);
    expect(primary(tester).onPressed, isNull);
  });

  testWidgets('номер занят — ошибка сервера, лист открыт', (tester) async {
    await openSheet(
      tester,
      onRequest: (_) async => const PhoneCodeSent(devCode: '1234'),
      onConfirm: (_, _) async =>
          throw ApiException(422, '{"message":"x","errors":{"phone":["Номер уже привязан к другому аккаунту."]}}'),
    );

    await enterPhone(tester, '9000000021');
    await tester.tap(find.text('Получить код'));
    await tester.pump();
    await tester.tap(find.text('Сменить номер'));
    await tester.pumpAndSettle();

    expect(find.text('Номер уже привязан к другому аккаунту.'), findsOneWidget);
    expect(find.text('Новый номер'), findsOneWidget);

    // «Изменить номер» возвращает к вводу номера
    await tester.tap(find.text('Изменить номер'));
    await tester.pump();
    expect(find.text('Получить код'), findsOneWidget);
    expect(find.text('Номер уже привязан к другому аккаунту.'), findsNothing);
  });
}
