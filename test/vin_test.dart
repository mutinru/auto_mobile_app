import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FieldBoxInput(
          label: 'VIN',
          controller: c,
          inputFormatters: const [VinFormatter()],
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'xw8zzz61zkg0kx24pQQQ');
    expect(c.text, 'XW8ZZZ61ZKG0KX24P');
  });
}
