import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/data/mock_verification_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_response.dart';
import 'package:auto_podbor_mobile/models/order_response_status.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/time_slot.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/nearby_orders_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/state/verification_status.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Перенос осмотра: отклик под прежнюю дату устарел (outdated) —
/// исполнитель откликается снова; отказавшийся до переноса и сорвавший
/// срок — нет (сервер ответил бы 422).
void main() {
  // в моке «я» — пользователь 1; заказчик — другой
  const me = UserSummary(id: 1, name: 'Андрей С.');
  const customer = UserSummary(id: 2, name: 'Ольга К.');

  Order order({OrderResponseStatus? mine}) => Order(
    id: 601,
    kind: OrderKind.inspection,
    status: OrderStatus.awaitingExecutor,
    brand: 'Kia',
    model: 'Rio',
    yearFrom: 2019,
    customer: customer,
    cities: const ['Химки'],
    address: 'ул. Ленина, 5',
    inspectOn: DateTime(2099, 11, 5),
    timeSlot: TimeSlot.day,
    askingPrice: 3500,
    responses: [
      if (mine != null)
        OrderResponse(
          id: 9,
          status: mine,
          proposedPrice: 3000,
          executor: me,
        ),
    ],
  );

  test('статус outdated с сервера и его подпись', () {
    expect(
      orderResponseStatusFromApi('outdated'),
      OrderResponseStatus.outdated,
    );
    expect(OrderResponseStatus.outdated.label, 'дата перенесена');
  });

  test('кнопка отклика — по состоянию своего отклика', () {
    final cases = {
      null: (true, 'Откликнуться', false),
      OrderResponseStatus.outdated: (true, 'Откликнуться снова', false),
      OrderResponseStatus.pending: (false, 'Вы откликнулись', true),
      OrderResponseStatus.accepted: (false, 'Вы откликнулись', true),
      OrderResponseStatus.declined: (false, 'Вы отказались', false),
      OrderResponseStatus.expired: (false, 'Вы не успели', false),
      OrderResponseStatus.rejected: (false, 'Вы откликнулись', false),
    };
    cases.forEach((status, expected) {
      final o = order(mine: status);
      expect(
        (o.canViewerRespond, o.respondLabel, o.hasViewerResponse),
        expected,
        reason: '$status',
      );
    });
  });

  testWidgets('устаревший отклик: «Откликнуться снова», отклик оживает', (
    tester,
  ) async {
    final repo = MockOrderRepository(
      orders: [order(mine: OrderResponseStatus.outdated)],
    );
    final store = OrderStore(
      repo,
      catalog: MockCarCatalogRepository(),
      cities: MockCityRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: NearbyOrdersScreen(
          store: store,
          verification: VerificationStatus(
            MockVerificationRepository(passed: 0, required: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // устаревший не считается ни в «N откл.», ни как «Ваш отклик»
    expect(find.text('Ваш отклик'), findsNothing);
    final again = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Откликнуться снова'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(again.onPressed, isNotNull);

    await store.respondToOrder(601, proposedPrice: 4200);
    await tester.pumpAndSettle();

    final updated = await repo.fetchOrder(601);
    expect(updated.responses.single.id, 9);
    expect(updated.responses.single.status, OrderResponseStatus.pending);
    expect(updated.responses.single.proposedPrice, 4200);
    expect(find.text('Вы откликнулись'), findsOneWidget);
  });
}
