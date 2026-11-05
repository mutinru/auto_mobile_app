import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/models/vin_kind.dart';
import 'package:auto_podbor_mobile/widgets/vin_frame.dart';

/// Номер берётся со строки, на которую наводили рамку, а не с верхней
/// надписи таблички (QA 2026-11-05 №4).
void main() {
  /// Табличка из прогона QA: строки сверху вниз, по 40 px.
  OcrLine line(String text, double top) =>
      (text: text, box: Rect.fromLTWH(100, top, 800, 30));

  final plate = [
    line('CIA MOTORS RUS MODEL RIO 1.6', 100),
    line('TYPE QB ENG G4FC 2018', 140),
    // OCR ошибся в двух знаках — слова ровно из 17 «VIN-знаков» нет
    line('XW8ZZZ61ZKGL98111', 180),
    line('MAX 1650 KG 1-860 KG 2-1000 KG', 220),
    line('PAINT 9P TRIM WK 3407', 260),
  ];

  test('рамка на строке VIN — строка VIN, а не соседняя', () {
    final text = textNearest(plate, 195);
    expect(text.split('\n').first, 'XW8ZZZ61ZKGL98111');
    expect(guessVin(text), 'XW8ZZZ61ZKGL98111');
  });

  test('целый VIN ниже по табличке побеждает, если рамка на нём', () {
    final lines = [
      line('WAUZZZ8V0JA000001', 100),
      line('XW8ZZZ61ZKG100111', 300),
    ];
    expect(extractVin(textNearest(lines, 310)), 'XW8ZZZ61ZKG100111');
    expect(extractVin(textNearest(lines, 110)), 'WAUZZZ8V0JA000001');
  });

  test('при равном расстоянии — порядок ML Kit сохраняется', () {
    final lines = [line('A', 100), line('B', 200)];
    expect(textNearest(lines, 165), 'A\nB');
  });
}
