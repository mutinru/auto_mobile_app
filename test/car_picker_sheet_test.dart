import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/car_picker_sheet.dart';

void main() {
  /// Кнопка открывает лист; выбор складывается в [result].
  Future<List<CarChoice?>> pumpPicker(
    WidgetTester tester, {
    MockCarCatalogRepository? catalog,
    String initialBrand = '',
  }) async {
    final result = <CarChoice?>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result.add(await showCarPickerSheet(
              context,
              catalog: catalog ?? MockCarCatalogRepository(),
              initialBrand: initialBrand,
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('марка, затем модель из справочника', (tester) async {
    final result = await pumpPicker(tester);

    expect(find.text('ПОПУЛЯРНЫЕ'), findsOneWidget);
    await tester.tap(find.text('Toyota').first);
    await tester.pumpAndSettle();

    expect(find.text('1994–2026'), findsOneWidget);
    await tester.tap(find.text('Camry'));
    await tester.pumpAndSettle();

    expect(result.single?.brand, 'Toyota');
    expect(result.single?.model, 'Camry');
  });

  testWidgets('поиск по-русски находит латинское название', (tester) async {
    await pumpPicker(tester);

    await tester.enterText(find.byType(TextField), 'тойо');
    await tester.pumpAndSettle();

    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('Kia'), findsNothing);
  });

  testWidgets('марки нет в списке — вписываем свою', (tester) async {
    final result = await pumpPicker(tester);

    await tester.enterText(find.byType(TextField), 'Самоделкин');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Указать «Самоделкин»'));
    await tester.pumpAndSettle();

    // марка перенеслась из поиска, модель — с нуля
    await tester.enterText(find.byType(TextField).last, 'Гаражный');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    expect(result.single?.brand, 'Самоделкин');
    expect(result.single?.model, 'Гаражный');
  });

  testWidgets('модели нет в списке — марка остаётся из справочника', (tester) async {
    final result = await pumpPicker(tester);

    await tester.tap(find.text('Kia').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ceed SW');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Указать «Ceed SW»'));
    await tester.pumpAndSettle();

    expect(result.single?.brand, 'Kia');
    expect(result.single?.model, 'Ceed SW');
  });

  testWidgets('марка из заказа открывает сразу её модели', (tester) async {
    await pumpPicker(tester, initialBrand: 'toyota');

    expect(find.text('Camry'), findsOneWidget);
    expect(find.text('ПОПУЛЯРНЫЕ'), findsNothing);
  });

  testWidgets('без сети — ручной ввод', (tester) async {
    final result = await pumpPicker(
      tester,
      catalog: MockCarCatalogRepository(fail: true),
    );

    expect(find.text('Не удалось загрузить список'), findsOneWidget);
    await tester.tap(find.text('Ввести вручную'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'BMW');
    await tester.enterText(find.byType(TextField).last, 'X3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    expect(result.single?.brand, 'BMW');
    expect(result.single?.model, 'X3');
  });
}
