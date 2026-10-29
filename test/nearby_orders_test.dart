import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/data/mock_verification_repository.dart';
import 'package:auto_podbor_mobile/screens/nearby_orders_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

void main() {
  Widget app({int passed = 0, bool required = true}) => MaterialApp(
    theme: AppTheme.dark,
    home: NearbyOrdersScreen(
      store: OrderStore(MockOrderRepository(), catalog: MockCarCatalogRepository(), cities: MockCityRepository()),
      verification: MockVerificationRepository(
        passed: passed,
        required: required,
      ),
    ),
  );

  /// Кнопка отклика внутри первой карточки: в моке теперь два свободных
  /// заказа — разовый осмотр и подбор.
  ElevatedButton respondButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(
        find
            .ancestor(
              of: find.text('Откликнуться'),
              matching: find.byType(ElevatedButton),
            )
            .first,
      );

  testWidgets('показывает свободный заказ и гейт верификации', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // мок отдаёт один заказ в статусе awaiting_executor и без города
    expect(find.text('Volkswagen Tiguan 2019+'), findsOneWidget);
    expect(find.text('Смотреть можно, откликаться — нет'), findsOneWidget);
    expect(find.text('Стать исполнителем'), findsOneWidget);

    // чужой отклик на 10 000 ₽ виден только числом — цены конкурента нет
    expect(find.text('Откликаются от'), findsNothing);
    expect(find.text('10 000 ₽'), findsNothing);
    expect(find.text('предлагаете вы'), findsOneWidget);
    expect(find.textContaining('1 отклик'), findsOneWidget);
  });

  testWidgets('без верификации кнопка отклика неактивна', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(respondButton(tester).onPressed, isNull);
  });

  testWidgets('после верификации гейт исчезает, отклик доступен', (
    tester,
  ) async {
    await tester.pumpWidget(app(passed: 4));
    await tester.pumpAndSettle();

    expect(find.text('Смотреть можно, откликаться — нет'), findsNothing);
    expect(respondButton(tester).onPressed, isNotNull);
  });

  testWidgets('верификация не обязательна — гейта нет, отклик доступен сразу', (
    tester,
  ) async {
    await tester.pumpWidget(app(required: false));
    await tester.pumpAndSettle();

    expect(find.text('Смотреть можно, откликаться — нет'), findsNothing);
    expect(respondButton(tester).onPressed, isNotNull);
  });

  test('мок отдаёт исполнителю только свой отклик, остальные — числом', () async {
    final repo = MockOrderRepository();
    final tiguan = (await repo.fetchAvailableOrders())
        .firstWhere((o) => o.brand == 'Volkswagen');
    expect(tiguan.responses, isEmpty);
    expect(tiguan.responsesCount, 1);

    final after = await repo.respondToOrder(tiguan.id, proposedPrice: 9000);
    expect(after.responses.map((r) => r.proposedPrice), [9000]);
    expect(after.responsesCount, 2);
  });

  testWidgets('после отклика заказ остаётся в ленте с погашенной кнопкой', (
    tester,
  ) async {
    final store = OrderStore(MockOrderRepository(), catalog: MockCarCatalogRepository(), cities: MockCityRepository());
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: NearbyOrdersScreen(
        store: store,
        verification: MockVerificationRepository(passed: 0, required: false),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Вы откликнулись'), findsNothing);

    final tiguan = store.availableOrders.firstWhere((o) => o.brand == 'Volkswagen');
    await store.respondToOrder(tiguan.id, proposedPrice: 9000);
    await tester.pumpAndSettle();

    expect(find.text('Volkswagen Tiguan 2019+'), findsOneWidget);
    expect(find.text('Ваш отклик'), findsOneWidget);
    expect(find.text('9 000 ₽'), findsOneWidget);
    expect(find.textContaining('2 отклика'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.ancestor(
      of: find.text('Вы откликнулись'),
      matching: find.byType(ElevatedButton),
    ));
    expect(button.onPressed, isNull);
  });

  testWidgets('фильтр «Мало откликов» оставляет заказ с одним откликом', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Мало откликов'));
    await tester.pump();

    expect(find.text('Volkswagen Tiguan 2019+'), findsOneWidget);
    expect(find.text('Все · 2'), findsOneWidget);
  });

  testWidgets('шторка фильтров: «Осмотр» прячет подбор, крестик возвращает', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Volkswagen Tiguan 2019+'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Фильтры'), findsOneWidget);

    await tester.tap(find.text('Осмотр'));
    await tester.pump();
    await tester.tap(find.text('Показать 1 заказ'));
    await tester.pumpAndSettle();

    expect(find.text('Volkswagen Tiguan 2019+'), findsNothing);
    expect(find.text('BMW X3 2017'), findsOneWidget);
    // бейдж на кнопке и чип включённого фильтра под шапкой
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Осмотр  ✕'), findsOneWidget);

    await tester.tap(find.text('Осмотр  ✕'));
    await tester.pump();

    expect(find.text('Volkswagen Tiguan 2019+'), findsOneWidget);
    expect(find.text('Осмотр  ✕'), findsNothing);
  });
}
