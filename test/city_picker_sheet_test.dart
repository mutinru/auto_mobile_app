import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/location_service.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/screens/new_order_screen.dart';
import 'package:auto_podbor_mobile/state/city_locator.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/city_picker_sheet.dart';

/// Геопозиция без плагина: [point] — что «вернул GPS», [calls] — сколько раз спросили.
class FakeLocation implements LocationService {
  FakeLocation(this.point);

  final (double, double)? point;
  int calls = 0;

  @override
  Future<(double, double)?> current() async {
    calls++;
    return point;
  }
}

const kazan = (55.79, 49.12);
const khimki = (55.89, 37.44);

void main() {
  /// Кнопка открывает лист; выбор складывается в [result].
  Future<List<Set<String>?>> pumpPicker(
    WidgetTester tester, {
    MockCityRepository? cities,
    Set<String> selected = const {},
    CityLocator? locator,
  }) async {
    final result = <Set<String>?>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result.add(await showCityPickerSheet(
              context,
              cities: cities ?? MockCityRepository(),
              selected: selected,
              locator: locator,
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

  /// Ввод в поиск с паузой дольше дебаунса листа.
  Future<void> typeQuery(WidgetTester tester, String q) async {
    await tester.enterText(find.byType(TextField), q);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  Future<void> done(WidgetTester tester) async {
    await tester.tap(find.textContaining('Готово'));
    await tester.pumpAndSettle();
  }

  testWidgets('без запроса — крупные города, поиск сужает список', (tester) async {
    await pumpPicker(tester);
    expect(find.text('КРУПНЫЕ ГОРОДА'), findsOneWidget);
    expect(find.text('Москва'), findsOneWidget);

    await typeQuery(tester, 'каз');
    expect(find.text('Казань'), findsOneWidget);
    expect(find.text('Москва'), findsNothing);
  });

  testWidgets('несколько городов и «ё/е» в поиске', (tester) async {
    final result = await pumpPicker(tester);

    await tester.tap(find.text('Москва'));
    await typeQuery(tester, 'орел');
    await tester.tap(find.text('Орёл'));
    await tester.pump();
    await done(tester);

    expect(result.single, {'Москва', 'Орёл'});
  });

  testWidgets('«Вся Россия» снимает города и наоборот', (tester) async {
    final result = await pumpPicker(tester, selected: {'Москва', 'Химки'});

    await tester.tap(find.text('Вся Россия'));
    await tester.pump();
    await done(tester);
    expect(result.single, {'Вся Россия'});
  });

  testWidgets('город не из справочника — своей строкой', (tester) async {
    final result = await pumpPicker(tester, selected: {'Вся Россия'});

    await typeQuery(tester, 'Простоквашино');
    expect(find.text('В справочнике не нашлось'), findsOneWidget);
    await tester.tap(find.text('Указать «Простоквашино»'));
    await tester.pump();
    await done(tester);

    expect(result.single, {'Простоквашино'});
  });

  testWidgets('без сети — ошибка и «Повторить»', (tester) async {
    final cities = MockCityRepository(fail: true);
    await pumpPicker(tester, cities: cities);
    expect(find.text('Не удалось загрузить список'), findsOneWidget);

    cities.fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Санкт-Петербург'), findsOneWidget);
  });

  testWidgets('«Определить по геопозиции» добавляет ближайший город', (tester) async {
    final result = await pumpPicker(
      tester,
      locator: CityLocator(MockCityRepository(), FakeLocation(khimki)),
    );

    await tester.tap(find.text('Определить по геопозиции'));
    await tester.pumpAndSettle();
    await done(tester);
    expect(result.single, {'Химки'});
  });

  test('локатор запоминает удачу и не запоминает неудачу', () async {
    final found = FakeLocation(kazan);
    final locator = CityLocator(MockCityRepository(), found);
    expect((await locator.detect())?.name, 'Казань');
    expect((await locator.detect())?.name, 'Казань');
    expect(found.calls, 1);

    final denied = FakeLocation(null);
    final none = CityLocator(MockCityRepository(), denied);
    expect(await none.detect(), isNull);
    expect(await none.detect(), isNull);
    expect(denied.calls, 2);

    // сеть упала — тоже null, без исключения
    final offline = CityLocator(MockCityRepository(fail: true), FakeLocation(kazan));
    expect(await offline.detect(), isNull);
  });

  Future<void> pumpNewOrder(WidgetTester tester, {CityLocator? locator}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: NewOrderScreen(
        store: OrderStore(
          MockOrderRepository(),
          catalog: MockCarCatalogRepository(),
          cities: MockCityRepository(),
          locator: locator,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('новый заказ подставляет город по геопозиции', (tester) async {
    await pumpNewOrder(
      tester,
      locator: CityLocator(MockCityRepository(), FakeLocation(kazan)),
    );
    expect(find.text('Казань  ×'), findsOneWidget);
    expect(find.text('+ Ещё город'), findsOneWidget);
  });

  testWidgets('новый заказ без геопозиции — город не выбран', (tester) async {
    await pumpNewOrder(tester);
    expect(find.text('+ Выбрать город'), findsOneWidget);
    expect(find.text('Москва  ×'), findsNothing);
  });
}
