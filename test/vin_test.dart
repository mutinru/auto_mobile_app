import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/models/vin_kind.dart';
import 'package:auto_podbor_mobile/widgets/app_ui.dart';

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
}
