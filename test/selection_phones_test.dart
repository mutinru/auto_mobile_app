import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_response.dart';
import 'package:auto_podbor_mobile/models/order_response_status.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/respond_sheet.dart';

/// Подбор: после выбора исполнителя стороны видят телефоны друг друга
/// (counterpart_phone) и могут позвонить; до выбора об этом предупреждают.
void main() {
  const customer = UserSummary(id: 1, name: 'Максим К.');
  const executor = UserSummary(id: 10, name: 'Игорь В.');

  Order selection({
    OrderStatus status = OrderStatus.sourcing,
    UserSummary? assigned = executor,
    String? phone = '+79004445566',
    List<OrderResponse> responses = const [],
  }) => Order(
    id: 3201,
    status: status,
    brand: 'Skoda',
    model: 'Octavia',
    yearFrom: 2019,
    customer: customer,
    executor: assigned,
    price: assigned == null ? null : 20000,
    counterpartPhone: phone,
    responses: responses,
  );

  Future<void> pump(
    WidgetTester tester,
    Order order, {
    required bool viewerIsCustomer,
  }) async {
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
          viewerIsCustomer: viewerIsCustomer,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('номер другой стороны разбирается из counterpart_phone', () {
    final order = Order.fromJson({
      'id': 1,
      'kind': 'selection',
      'status': 'sourcing',
      'brand': 'Skoda',
      'model': 'Octavia',
      'customer': {'id': 1, 'name': 'Максим К.'},
      'counterpart_phone': '+79004445566',
    });
    expect(order.counterpartPhone, '+79004445566');
  });

  testWidgets('заказчик видит телефон исполнителя и «Позвонить»', (
    tester,
  ) async {
    await pump(tester, selection(), viewerIsCustomer: true);

    expect(find.text('Телефон исполнителя'), findsOneWidget);
    expect(find.text('+7 900 444 55 66'), findsOneWidget);
    expect(find.text('Позвонить'), findsOneWidget);
    expect(find.text('ЗАКАЗЧИК'), findsNothing);
  });

  testWidgets('исполнитель видит заказчика с телефоном, а не свой номер', (
    tester,
  ) async {
    await pump(
      tester,
      selection(phone: '+79001112233'),
      viewerIsCustomer: false,
    );

    expect(find.text('ЗАКАЗЧИК'), findsOneWidget);
    expect(find.text('Телефон заказчика'), findsOneWidget);
    expect(find.text('+7 900 111 22 33'), findsOneWidget);
    expect(find.text('Телефон исполнителя'), findsNothing);
  });

  testWidgets('до выбора — предупреждение об обмене номерами, без номера', (
    tester,
  ) async {
    await pump(
      tester,
      selection(
        status: OrderStatus.awaitingExecutor,
        assigned: null,
        phone: null,
        responses: const [
          OrderResponse(
            id: 5,
            status: OrderResponseStatus.pending,
            proposedPrice: 20000,
            executor: executor,
          ),
        ],
      ),
      viewerIsCustomer: true,
    );

    expect(
      find.textContaining('вы увидите телефоны друг друга'),
      findsOneWidget,
    );
    expect(find.text('Позвонить'), findsNothing);
  });

  testWidgets(
    'отклик на подбор предупреждает об обмене номерами, на осмотр — нет',
    (
      tester,
    ) async {
      Future<void> open(Order order) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showRespondSheet(
                    context,
                    order: order,
                    onSubmit: (_, _, _) async {},
                  ),
                  child: const Text('открыть'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('открыть'));
        await tester.pumpAndSettle();
      }

      const note = 'Если заказчик выберет вас';
      await open(
        selection(status: OrderStatus.awaitingExecutor, assigned: null),
      );
      expect(find.textContaining(note), findsOneWidget);

      await open(
        Order(
          id: 3202,
          kind: OrderKind.inspection,
          status: OrderStatus.awaitingExecutor,
          brand: 'Kia',
          model: 'Rio',
          customer: customer,
          askingPrice: 4000,
        ),
      );
      expect(find.textContaining(note), findsNothing);
    },
  );
}
