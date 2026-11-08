import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_verdict.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/inspection_overview_screen.dart';
import 'package:auto_podbor_mobile/screens/inspection_report_screen.dart';
import 'package:auto_podbor_mobile/screens/inspection_summary_screen.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Заказчик подбора видит итог по кандидату: комментарий к вердикту в
/// карточке и полный отчёт по тапу. Идущий осмотр — схема только для чтения.
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');
  const executor = UserSummary(id: 10, name: 'Максим К.');
  const comment = 'Бампер под замену, торг 50k';

  final order = Order(
    id: 3101,
    status: OrderStatus.inspecting,
    brand: 'Kia',
    model: 'Rio',
    yearFrom: 2018,
    customer: customer,
    executor: executor,
    price: 12000,
    cars: const [
      OrderCar(
        id: 81,
        brand: 'Kia',
        model: 'Rio',
        year: 2019,
        vinMasked: '··· 123456',
        inspectionId: 601,
        inspectionStatus: 'completed',
        verdict: InspectionVerdict.withReservations,
        verdictComment: comment,
      ),
      OrderCar(
        id: 82,
        brand: 'Kia',
        model: 'Rio',
        year: 2020,
        vinMasked: '··· 654321',
        inspectionId: 602,
        inspectionStatus: 'in_progress',
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, {bool asCustomer = true}) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OrderDetailScreen(
          store: OrderStore(
            MockOrderRepository(orders: [order]),
            catalog: MockCarCatalogRepository(),
            cities: MockCityRepository(),
          ),
          orderId: order.id,
          viewerIsCustomer: asCustomer,
          inspectionRepository: (_) => MockInspectionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('комментарий к вердикту виден в карточке кандидата', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(comment), findsOneWidget);
    expect(find.text('С ОГОВОРКАМИ'), findsOneWidget);
  });

  testWidgets('осмотренный кандидат открывает отчёт с итогом', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Kia Rio 2019'));
    await tester.pumpAndSettle();

    expect(find.byType(InspectionReportScreen), findsOneWidget);
    expect(find.text('Отчёт'), findsOneWidget);
    expect(find.text('ИТОГ ОСМОТРА'), findsOneWidget);
    expect(find.text('С оговорками'), findsOneWidget);
    expect(find.text(comment), findsOneWidget);
    // пробег по одометру и «заявлено» — из осмотра
    expect(find.text('ПРОБЕГ'), findsOneWidget);
  });

  testWidgets('идущий осмотр — схема только для чтения, не отчёт', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Kia Rio 2020'));
    await tester.pumpAndSettle();

    expect(find.byType(InspectionReportScreen), findsNothing);
    expect(find.byType(InspectionOverviewScreen), findsOneWidget);
  });

  testWidgets('исполнитель: осмотренный кандидат — только отчёт, без правки', (
    tester,
  ) async {
    // без auth исполнитель не опознаётся, но правило от этого не зависит:
    // завершённый осмотр открывается отчётом у любого
    await pump(tester, asCustomer: false);
    await tester.tap(find.text('Kia Rio 2019'));
    await tester.pumpAndSettle();

    expect(find.byType(InspectionReportScreen), findsOneWidget);
    expect(find.text('Завершить осмотр'), findsNothing);
  });

  testWidgets('сводка без отправки — без пустой кнопки (№14)', (tester) async {
    final store = InspectionStore(MockInspectionRepository());
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionSummaryScreen(
          store: store,
          sendLabel: 'Завершить осмотр',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Завершить осмотр'), findsNothing);
  });
}
