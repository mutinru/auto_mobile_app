import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/data/mock_verification_repository.dart';
import 'package:auto_podbor_mobile/screens/nearby_orders_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

void main() {
  Widget app({int passed = 0}) => MaterialApp(
        theme: AppTheme.dark,
        home: NearbyOrdersScreen(
          store: OrderStore(MockOrderRepository()),
          verification: MockVerificationRepository(passed: passed),
        ),
      );

  /// Кнопка отклика внутри первой карточки: в моке теперь два свободных
  /// заказа — разовый осмотр и подбор.
  ElevatedButton respondButton(WidgetTester tester) => tester.widget<ElevatedButton>(
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

    // один отклик на 10 000 ₽ → гонорара у заказа нет, берём минимум из откликов
    expect(find.text('Откликаются от'), findsOneWidget);
    expect(find.text('10 000 ₽'), findsOneWidget);
  });

  testWidgets('без верификации кнопка отклика неактивна', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(respondButton(tester).onPressed, isNull);
  });

  testWidgets('после верификации гейт исчезает, отклик доступен', (tester) async {
    await tester.pumpWidget(app(passed: 4));
    await tester.pumpAndSettle();

    expect(find.text('Смотреть можно, откликаться — нет'), findsNothing);
    expect(respondButton(tester).onPressed, isNotNull);
  });

  testWidgets('фильтр «Мало откликов» оставляет заказ с одним откликом',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Мало откликов'));
    await tester.pump();

    expect(find.text('Volkswagen Tiguan 2019+'), findsOneWidget);
    expect(find.text('Все · 2'), findsOneWidget);
  });
}
