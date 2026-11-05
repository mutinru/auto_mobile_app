import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/models/vin_kind.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/app_ui.dart';
import 'package:auto_podbor_mobile/widgets/vin_capture.dart';

void main() {
  const f = VinFormatter();

  TextEditingValue apply(String input) => f.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: input,
      selection: TextSelection.collapsed(offset: input.length),
    ),
  );

  test('обрезает до 17 знаков', () {
    expect(apply('XW8ZZZ61ZKG0KX24PZZZZ').text, 'XW8ZZZ61ZKG0KX24P');
    expect(apply('XW8ZZZ61ZKG0KX24PZZZZ').text.length, 17);
  });

  test('приводит к верхнему регистру', () {
    expect(apply('xw8zzz61').text, 'XW8ZZZ61');
  });

  test('выбрасывает I, O, Q и разделители', () {
    expect(apply('XW8-IOQ 61').text, 'XW861');
  });

  testWidgets('поле VIN принимает форматтер', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FieldBoxInput(
            label: 'VIN',
            controller: c,
            inputFormatters: const [VinFormatter()],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'xw8zzz61zkg0kx24pQQQ');
    expect(c.text, 'XW8ZZZ61ZKG0KX24P');
  });

  group('распознавание таблички', () {
    test('VIN — 17 знаков без I, O, Q, разделители выбрасываются', () {
      expect(
        extractVin('VIN: XW8 ZZZ61Z KG100111\nMADE IN'),
        'XW8ZZZ61ZKG100111',
      );
      expect(extractVin('нет тут номера'), isNull);
    });

    test('номер кузова — модель шасси и серийный номер через дефис', () {
      expect(extractBodyNumber('FRAME NO. gx110 - 6012345'), 'GX110-6012345');
      expect(extractBodyNumber('JZX100 0123456'), 'JZX100-0123456');
      expect(extractBodyNumber('TOYOTA MOTOR'), isNull);
    });

    test('проверка — как у сервера', () {
      expect(VinKind.vin.problem('XW8ZZZ61ZKG100111'), isNull);
      expect(VinKind.vin.problem('XW8ZZZ61ZKG10011'), isNotNull);
      expect(VinKind.bodyNumber.problem('GX110-6012345'), isNull);
      expect(VinKind.bodyNumber.problem('GX110'), isNotNull);
      expect(vinKindFromApi('body_number'), VinKind.bodyNumber);
    });

    test('поле номера кузова оставляет дефис и верхний регистр', () {
      final v = const BodyNumberFormatter().formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'gx110-6012345 '),
      );
      expect(v.text, 'GX110-6012345');
    });
  });

  group('сверка распознанного VIN', () {
    Future<void> pump(WidgetTester tester, VinCaptureController c) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(child: VinCapture(controller: c)),
            ),
          ),
        );

    /// Как после удачного снимка: фото, текст, отметка распознавания.
    VinCaptureController recognized() {
      final c = VinCaptureController()..setPhoto('/tmp/plate.jpg');
      c.text.text = 'XW8ZZZ61ZKG100111';
      c.markRecognized();
      return c;
    }

    testWidgets('после распознавания — «Проверьте VIN» и «Исправить»', (
      tester,
    ) async {
      final c = recognized();
      await pump(tester, c);

      expect(find.textContaining('Проверьте VIN'), findsOneWidget);
      expect(find.text('Исправить'), findsOneWidget);

      // «Исправить» сразу открывает поле, минуя выбор «снять / ввести»
      await tester.tap(find.text('Исправить'));
      await tester.pumpAndSettle();
      expect(find.text('Сфотографировать табличку'), findsNothing);
      expect(find.byType(FieldBoxInput), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'XW8ZZZ61ZKG100112');
      await tester.tap(find.text('Всё верно'));
      await tester.pumpAndSettle();

      expect(c.value, 'XW8ZZZ61ZKG100112');
      expect(find.textContaining('Проверьте VIN'), findsNothing);
      c.dispose();
    });

    testWidgets('ручной ввод без снимка-распознавания — без подсказки', (
      tester,
    ) async {
      final c = VinCaptureController()..setPhoto('/tmp/plate.jpg');
      c.text.text = 'XW8ZZZ61ZKG100111';
      await pump(tester, c);

      expect(find.textContaining('Проверьте'), findsNothing);
      c.dispose();
    });

    testWidgets('переход на номер кузова убирает подсказку', (tester) async {
      final c = recognized();
      await pump(tester, c);

      await tester.tap(find.text('Нет VIN? Указать номер кузова'));
      await tester.pump();

      expect(c.needsCheck, isFalse);
      expect(find.textContaining('Проверьте'), findsNothing);
      c.dispose();
    });

    testWidgets(
      'неполный VIN: «Всё верно» не закрывает шторку, пока не допишут',
      (
        tester,
      ) async {
        // распознали 16 знаков из 17 — так и показываем
        final c = VinCaptureController()..setPhoto('/tmp/plate.jpg');
        c.text.text = 'XW8ZZZ61ZKG10011';
        c.markRecognized();
        await pump(tester, c);

        await tester.tap(find.text('Исправить'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(TextField),
            matching: find.text('XW8ZZZ61ZKG10011'),
          ),
          findsOneWidget,
        );

        // открыта руками со снимком — серое пояснение под полем
        expect(find.text('Сверьте с табличкой на фото'), findsOneWidget);

        await tester.tap(find.text('Всё верно'));
        await tester.pumpAndSettle();
        expect(
          find.text('В VIN 17 символов, сейчас 16 — сверьте с фото'),
          findsOneWidget,
        );
        // ошибка — вместо пояснения
        expect(find.text('Сверьте с табличкой на фото'), findsNothing);
        expect(
          find.text('Всё верно'),
          findsOneWidget,
          reason: 'шторка открыта',
        );
        expect(c.needsCheck, isTrue);

        await tester.enterText(find.byType(TextField), 'XW8ZZZ61ZKG100111');
        await tester.pump();
        expect(find.textContaining('сейчас 16'), findsNothing);
        // поправили — ошибка ушла, пояснение вернулось
        expect(find.text('Сверьте с табличкой на фото'), findsOneWidget);
        await tester.tap(find.text('Всё верно'));
        await tester.pumpAndSettle();

        expect(find.text('Всё верно'), findsNothing);
        expect(c.value, 'XW8ZZZ61ZKG100111');
        expect(c.needsCheck, isFalse);
        c.dispose();
      },
    );

    testWidgets('смахнули шторку — подсказка «Проверьте VIN» остаётся', (
      tester,
    ) async {
      final c = recognized();
      await pump(tester, c);

      await tester.tap(find.text('Исправить'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // мимо шторки
      await tester.pumpAndSettle();

      expect(find.textContaining('Проверьте VIN'), findsOneWidget);
      c.dispose();
    });
  });

  testWidgets('пустое поле подсказывает, что вводить, а не номер-образец', (
    tester,
  ) async {
    final c = VinCaptureController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: VinCapture(controller: c)),
      ),
    );
    await tester.tap(find.text('нажмите, чтобы снять табличку'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ввести вручную'));
    await tester.pumpAndSettle();

    expect(find.text('17 знаков с таблички'), findsOneWidget);
    expect(find.text('XW8ZZZ61ZKG0KX24P'), findsNothing);
    c.dispose();
  });

  group('guessVin', () {
    test('целый VIN — как extractVin', () {
      expect(guessVin('VIN XW8ZZZ61ZKG100111'), 'XW8ZZZ61ZKG100111');
    });

    test('неполный VIN отдаётся как есть', () {
      expect(guessVin('MODEL RIO\nXW8ZZZ61ZKG10011'), 'XW8ZZZ61ZKG10011');
    });

    test('O, I и Q из OCR становятся 0 и 1', () {
      expect(guessVin('W8ZZZ61ZVKGIO011'), 'W8ZZZ61ZVKG10011');
    });

    test('больше двух замен I/O/Q — мусор, а не VIN', () {
      // текст, прочитанный вверх ногами: много I и O, мало цифр
      expect(guessVin('WIIOOTSYNZT9ZZZ8M4X'), isNull);
    });

    test('меньше четырёх цифр — не VIN', () {
      expect(guessVin('WIAXTSYNZT9ZZZ8MX'), isNull);
    });

    test('строка шильдика с массами — не VIN (QA 2026-11-05 №4)', () {
      // без пробелов и дефисов она даёт 17 «VIN-знаков»: WAX1650KG1860KG28
      const masses = 'MAX 1650 KG 1-860 KG 2-1000 KG';
      expect(extractVin(masses), isNull);
      expect(guessVin(masses), isNull);
      // а VIN, разбитый OCR на три куска, по-прежнему склеивается
      expect(guessVin('VIN: XW8 ZZZ61Z KG10011'), 'XW8ZZZ61ZKG10011');
    });

    test('надписи без цифр и короткие строки — не VIN', () {
      expect(guessVin('TOYOTA MOTOR CORPORATION'), isNull);
      expect(guessVin('MAX 1850 KG'), isNull);
    });
  });
}
