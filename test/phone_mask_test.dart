import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/screens/phone_login_screen.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: PhoneLoginScreen(auth: AuthService(), onLoggedIn: () {}),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('маска форматирует номер по мере ввода', (tester) async {
    await pump(tester);
    final field = find.byType(TextField).first;

    await tester.enterText(field, '9254316812');
    await tester.pump();

    expect(find.text('925 431 68 12'), findsOneWidget);
  });

  testWidgets('ввод обрезается на десятой цифре', (tester) async {
    await pump(tester);
    final field = find.byType(TextField).first;

    await tester.enterText(field, '92543168129999');
    await tester.pump();

    expect(find.text('925 431 68 12'), findsOneWidget);
  });

  testWidgets('нецифры игнорируются', (tester) async {
    await pump(tester);
    final field = find.byType(TextField).first;

    await tester.enterText(field, '925-abc-431');
    await tester.pump();

    expect(find.text('925 431'), findsOneWidget);
  });
}
