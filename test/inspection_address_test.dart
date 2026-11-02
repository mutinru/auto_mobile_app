import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/address_repository.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/screens/new_inspection_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/address_field.dart';

/// «Где и когда» в форме осмотра: город из справочника и адрес с подсказками.
void main() {
  group('AddressField', () {
    late TextEditingController controller;
    late List<AddressPoint?> points;

    Future<void> pump(
      WidgetTester tester, {
      AddressRepository? addresses,
    }) async {
      controller = TextEditingController();
      points = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: AddressField(
              controller: controller,
              addresses: addresses,
              cityId: 'khimki',
              onPoint: points.add,
            ),
          ),
        ),
      );
    }

    testWidgets(
      'подсказка: выбор ставит адрес и точку, правка точку сбрасывает',
      (tester) async {
        await pump(tester, addresses: MockAddressRepository());

        await tester.enterText(find.byType(TextField), 'лен');
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pumpAndSettle();
        expect(find.text('ул Ленина, д 5'), findsOneWidget);
        expect(find.text('ул Ленинградская, д 12'), findsOneWidget);

        await tester.tap(find.text('ул Ленина, д 5'));
        await tester.pumpAndSettle();
        expect(controller.text, 'ул Ленина, д 5');
        expect(points.single?.precision, 0);
        // список закрылся
        expect(find.text('ул Ленинградская, д 12'), findsNothing);

        await tester.enterText(
          find.byType(TextField),
          'ул Ленина, д 5, подъезд 2',
        );
        await tester.pump();
        expect(points.last, isNull);
      },
    );

    testWidgets('короче трёх букв — без подсказок', (tester) async {
      await pump(tester, addresses: MockAddressRepository());

      await tester.enterText(find.byType(TextField), 'ул');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.location_on_outlined), findsNothing);
    });

    testWidgets('без репозитория — обычное текстовое поле', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'парковка ТЦ, вход 3');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(controller.text, 'парковка ТЦ, вход 3');
      expect(points, isEmpty);
    });
  });

  testWidgets('город осмотра выбирается одним тапом, без «Вся Россия»', (
    tester,
  ) async {
    final store = OrderStore(
      MockOrderRepository(),
      catalog: MockCarCatalogRepository(),
      cities: MockCityRepository(),
      addresses: MockAddressRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: NewInspectionScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    // поле ниже первого экрана, а ListView строит его только при прокрутке
    await tester.scrollUntilVisible(
      find.text('Выбрать город'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Выбрать город'));
    await tester.pumpAndSettle();
    expect(find.text('Вся Россия'), findsNothing);
    expect(find.text('Готово'), findsNothing);

    await tester.tap(find.text('Химки'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрать город'), findsNothing);
    expect(find.text('Химки'), findsOneWidget);
  });
}
