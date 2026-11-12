import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_outcome.dart';
import 'package:auto_podbor_mobile/models/inspection_verdict.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/order_response.dart';
import 'package:auto_podbor_mobile/models/order_response_status.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_colors.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/response_card.dart';

/// Отклики подбора у заказчика: выбранный видно сразу — он первым, в
/// зелёной рамке и с плашкой, а не серым словом «принят» сбоку.
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');
  const chosen = UserSummary(id: 10, name: 'Игорь В.');
  const other = UserSummary(id: 11, name: 'Пётр Н.');

  Order selection(List<OrderResponse> responses) => Order(
    id: 3101,
    status: OrderStatus.sourcing,
    brand: 'Skoda',
    model: 'Octavia',
    yearFrom: 2019,
    customer: customer,
    executor: chosen,
    price: 20000,
    responses: responses,
  );

  Future<void> pump(WidgetTester tester, Order order) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OrderDetailScreen(
          store: OrderStore(
            MockOrderRepository(orders: [order]),
            catalog: MockCarCatalogRepository(),
            cities: MockCityRepository(),
          ),
          orderId: order.id,
          viewerIsCustomer: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('выбранный отклик — первым, с плашкой и в зелёной рамке', (
    tester,
  ) async {
    await pump(
      tester,
      selection(const [
        OrderResponse(
          id: 1,
          status: OrderResponseStatus.rejected,
          proposedPrice: 18000,
          executor: other,
        ),
        OrderResponse(
          id: 2,
          status: OrderResponseStatus.accepted,
          proposedPrice: 20000,
          executor: chosen,
        ),
      ]),
    );
    await tester.scrollUntilVisible(find.text('ВЫБРАН'), 200);

    final cards = tester
        .widgetList<ResponseCard>(find.byType(ResponseCard))
        .toList();
    expect(cards.map((c) => c.response.id), [2, 1]);
    expect(find.text('ОТКЛОНЁН'), findsOneWidget);
    // решённым откликам кнопка выбора не положена
    expect(find.text('Выбрать'), findsNothing);

    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byWidget(cards.first),
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (box.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AppColors.light.buyEdge);
  });

  testWidgets('ждущий отклик можно выбрать, пока исполнитель не выбран', (
    tester,
  ) async {
    // выбрать можно только в awaiting_executor (actions.accept_response):
    // в идущем подборе сервер ответил бы 422 «Исполнитель уже выбран»
    await pump(
      tester,
      Order(
        id: 3101,
        status: OrderStatus.awaitingExecutor,
        brand: 'Skoda',
        model: 'Octavia',
        yearFrom: 2019,
        customer: customer,
        responses: const [
          OrderResponse(
            id: 3,
            status: OrderResponseStatus.pending,
            proposedPrice: 15000,
            executor: other,
          ),
        ],
      ),
    );
    await tester.scrollUntilVisible(find.text('Выбрать'), 200);
    expect(find.text('Выбрать'), findsOneWidget);
  });

  testWidgets('купленный кандидат — в зелёной рамке, остальные — в обычной', (
    tester,
  ) async {
    await pump(
      tester,
      selection(const []).copyWith(
        cars: const [
          OrderCar(
            id: 81,
            brand: 'Skoda',
            model: 'Octavia',
            year: 2020,
            vinMasked: '··· 000081',
            inspectionId: 901,
            inspectionStatus: 'completed',
            inspectionOutcome: InspectionOutcome.purchased,
          ),
          OrderCar(
            id: 82,
            brand: 'Skoda',
            model: 'Octavia',
            year: 2019,
            vinMasked: '··· 000082',
            inspectionId: 902,
            inspectionStatus: 'completed',
            inspectionOutcome: InspectionOutcome.rejected,
            verdict: InspectionVerdict.withReservations,
          ),
        ],
      ),
    );

    Color edge(String label) {
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first,
      );
      return (material.shape! as RoundedRectangleBorder).side.color;
    }

    expect(edge('КУПЛЕНА'), AppColors.light.buyEdge);
    // некупленная — с вердиктом подборщика, без «не подошла»
    expect(edge('С ОГОВОРКАМИ'), AppColors.light.line);
    expect(find.text('НЕ ПОДОШЛА'), findsNothing);
  });
}
