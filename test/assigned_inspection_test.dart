import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/panel_condition.dart';
import 'package:auto_podbor_mobile/screens/assigned_inspection_screen.dart';
import 'package:auto_podbor_mobile/screens/inspection_summary_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Мок, в котором осмотр уже начат: штатный мок не двигает статус
/// при startInspection, а «Завершить» доступно только «на осмотре».
class _InspectingRepository extends MockOrderRepository {
  @override
  Future<Order> fetchOrder(int id) async {
    final order = await super.fetchOrder(id);
    return order.status == OrderStatus.scheduled
        ? order.copyWith(status: OrderStatus.inspecting)
        : order;
  }
}

/// Разовый осмотр в интерфейсе исполнителя.
void main() {
  Widget app(int orderId, [MockOrderRepository? repo]) => MaterialApp(
    theme: AppTheme.dark,
    home: AssignedInspectionScreen(
      store: OrderStore(repo ?? MockOrderRepository(), catalog: MockCarCatalogRepository(), cities: MockCityRepository()),
      orderId: orderId,
    ),
  );

  testWidgets('назначенный осмотр: гонорар, заказчик и «Начать осмотр»', (
    tester,
  ) async {
    await tester.pumpWidget(app(2051));
    await tester.pumpAndSettle();

    expect(find.text('Начать осмотр'), findsOneWidget);
    expect(find.text('Ваш гонорар'), findsOneWidget);
    expect(find.text('Андрей С.'), findsOneWidget);
    expect(find.text('+79161234567'), findsOneWidget);
    // экран исполнителя — без цены заказчика и выбора откликов
    expect(find.text('Ваша цена'), findsNothing);
    expect(find.text('Выбрать'), findsNothing);
  });

  testWidgets('завершённый осмотр: вердикт и никаких кнопок', (tester) async {
    await tester.pumpWidget(app(2047));
    await tester.pumpAndSettle();

    expect(find.text('Не рекомендую'), findsOneWidget);
    expect(find.text('Начать осмотр'), findsNothing);
    expect(find.text('Завершить осмотр'), findsNothing);
  });

  testWidgets('«Завершить осмотр» отправляет вердикт и показывает итог', (
    tester,
  ) async {
    await tester.pumpWidget(app(2051, _InspectingRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Продолжить осмотр'), findsOneWidget);
    await tester.tap(find.text('Завершить осмотр'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('С оговорками'));
    await tester.enterText(find.byType(TextField), 'Скол на капоте');
    await tester.tap(find.text('Отправить отчёт'));
    await tester.pumpAndSettle();

    expect(find.text('ИТОГ ОСМОТРА'), findsOneWidget);
    expect(find.text('С оговорками'), findsOneWidget);
    expect(find.text('Скол на капоте'), findsOneWidget);
    expect(find.text('Завершить осмотр'), findsNothing);
  });

  testWidgets('«Отправить отчёт клиенту» в сводке ведёт к вердикту', (
    tester,
  ) async {
    final store = InspectionStore(MockInspectionRepository());
    await store.load();
    for (final panel in store.panels) {
      await store.applyCondition(panel.id, PanelCondition.good);
    }
    var sent = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionSummaryScreen(
          store: store,
          onSendReport: () => sent = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отправить отчёт клиенту'));
    expect(sent, isTrue);
  });
}
