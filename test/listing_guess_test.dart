import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/screens/new_inspection_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Подсказка «Похоже, это …» под ссылкой на объявление в форме осмотра.
void main() {
  const avito = 'https://www.avito.ru/moskva/avtomobili/toyota_camry_2019_3456789012';

  Future<void> openForm(WidgetTester tester) async {
    final store = OrderStore(
      MockOrderRepository(),
      catalog: MockCarCatalogRepository(),
      cities: MockCityRepository(),
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: NewInspectionScreen(store: store),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> pasteLink(WidgetTester tester, String url) async {
    // первое поле формы — ссылка на объявление
    await tester.enterText(find.byType(TextField).first, url);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  final hint = find.textContaining('Похоже, это', findRichText: true);

  testWidgets('узнанная ссылка: подсказка, «Заполнить» заполняет поля', (tester) async {
    await openForm(tester);
    await pasteLink(tester, avito);

    expect(find.textContaining('Toyota Camry, 2019', findRichText: true), findsOneWidget);
    expect(find.text('Заполнить'), findsOneWidget);
    // без согласия поля не трогаем
    expect(find.text('Выбрать марку и модель'), findsOneWidget);

    await tester.tap(find.text('Заполнить'));
    await tester.pumpAndSettle();

    expect(find.text('Toyota Camry'), findsOneWidget);
    expect(find.text('2019'), findsOneWidget);
    expect(hint, findsNothing);
  });

  testWidgets('марка уже выбрана другая — кнопка «Заменить»', (tester) async {
    await openForm(tester);
    await pasteLink(tester, avito);
    await tester.tap(find.text('Заполнить'));
    await tester.pumpAndSettle();

    await pasteLink(tester, 'https://auto.drom.ru/moskva/vaz/granta/1.html');

    expect(find.textContaining('Lada (ВАЗ) Granta', findRichText: true), findsOneWidget);
    expect(find.text('Заменить'), findsOneWidget);
  });

  testWidgets('чужая ссылка — подсказки нет', (tester) async {
    await openForm(tester);
    await pasteLink(tester, 'https://example.com/cars/1');

    expect(hint, findsNothing);
  });

  testWidgets('✕ скрывает подсказку и для этой ссылки она не возвращается', (tester) async {
    await openForm(tester);
    await pasteLink(tester, avito);

    await tester.tap(find.byTooltip('Не то'));
    await tester.pumpAndSettle();
    expect(hint, findsNothing);

    await pasteLink(tester, '$avito ');
    expect(hint, findsNothing);
    expect(find.text('Выбрать марку и модель'), findsOneWidget);
  });

  testWidgets('пустое поле — строка помощи, не-ссылка — предупреждение', (tester) async {
    await openForm(tester);
    expect(find.text('Подставим марку, модель и год'), findsOneWidget);

    await pasteLink(tester, 'продавец скинет потом');
    expect(find.text('Похоже, это не ссылка'), findsOneWidget);
    expect(find.text('Подставим марку, модель и год'), findsNothing);
    expect(find.text('Заполнить'), findsNothing);

    // чужой сайт — ссылка, просто без подсказки марки
    await pasteLink(tester, 'https://example.com/car/1');
    expect(find.text('Похоже, это не ссылка'), findsNothing);
  });
}
