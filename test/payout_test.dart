import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/payout.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/payout_sheet.dart';
import 'package:auto_podbor_mobile/widgets/respond_sheet.dart';

/// Реквизиты: в форме отклика на разовый осмотр и в профиле.
void main() {
  const order = Order(
    id: 7,
    kind: OrderKind.inspection,
    status: OrderStatus.awaitingExecutor,
    brand: 'BMW',
    model: 'X3',
    yearFrom: 2017,
    askingPrice: 3500,
    customer: UserSummary(id: 1, name: 'Андрей С.'),
  );

  /// Кнопка, открывающая лист, — чтобы pop листа не снимал единственный маршрут.
  Widget host(void Function(BuildContext context) open) => MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(child: TextButton(onPressed: () => open(context), child: const Text('открыть'))),
          ),
        ),
      );

  Future<void> openSheet(WidgetTester tester, void Function(BuildContext context) open) async {
    await tester.pumpWidget(host(open));
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.descendant(
        of: find.ancestor(of: find.text(label.toUpperCase()), matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      );

  test('проверка карты по Луну', () {
    expect(isValidCard('4111 1111 1111 1111'), isTrue);
    expect(isValidCard('4111 1111 1111 1112'), isFalse);
    expect(isValidCard('4111'), isFalse);
  });

  testWidgets('первый отклик на осмотр просит реквизиты и отдаёт их', (tester) async {
    Payout? sent;
    await openSheet(
      tester,
      (context) => showRespondSheet(
        context,
        order: order,
        requiresPayout: true,
        onSubmit: (price, message, payout) async => sent = payout,
      ),
    );

    expect(find.text('КУДА ЗАКАЗЧИК ПЕРЕВЕДЁТ ОПЛАТУ'), findsOneWidget);
    await tester.enterText(field('Ваша цена'), '3500');
    await tester.enterText(field('Номер карты'), '4111111111111112');
    await tester.tap(find.text('Отправить отклик'));
    await tester.pumpAndSettle();

    expect(find.text('Проверьте номер карты'), findsOneWidget);
    expect(sent, isNull);

    await tester.enterText(field('Номер карты'), '4111111111111111');
    await tester.tap(find.text('Отправить отклик'));
    await tester.pumpAndSettle();

    expect(sent!.card, '4111111111111111');
    // лист закрылся
    expect(find.text('Отправить отклик'), findsNothing);
  });

  testWidgets('с реквизитами в профиле форма их не спрашивает', (tester) async {
    await openSheet(
      tester,
      (context) => showRespondSheet(context, order: order, onSubmit: (_, _, _) async {}),
    );

    expect(find.text('КУДА ЗАКАЗЧИК ПЕРЕВЕДЁТ ОПЛАТУ'), findsNothing);
  });

  testWidgets('ошибка сервера по реквизитам — у поля, лист не закрывается', (tester) async {
    await openSheet(
      tester,
      (context) => showRespondSheet(
        context,
        order: order,
        requiresPayout: true,
        onSubmit: (_, _, _) async => throw ApiException(
          422,
          '{"message":"x","errors":{"payout_card":["Номер карты отклонён банком."]}}',
        ),
      ),
    );

    await tester.enterText(field('Ваша цена'), '3500');
    await tester.enterText(field('Номер карты'), '4111111111111111');
    await tester.tap(find.text('Отправить отклик'));
    await tester.pumpAndSettle();

    expect(find.text('Номер карты отклонён банком.'), findsOneWidget);
    expect(find.text('Отправить отклик'), findsOneWidget);
  });

  testWidgets('реквизиты в профиле: СБП требует банк, телефон нормализуется', (tester) async {
    Payout? saved;
    await openSheet(
      tester,
      (context) => showPayoutSheet(context, onSave: (payout) async => saved = payout),
    );

    await tester.tap(find.text('СБП по телефону'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Телефон для СБП'), '8 900 111-22-33');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Укажите банк для СБП'), findsOneWidget);
    expect(saved, isNull);

    await tester.enterText(field('Банк'), 'Т-Банк');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(saved!.phone, '+79001112233');
    expect(saved!.bank, 'Т-Банк');
    expect(saved!.card, isNull);
  });
}
