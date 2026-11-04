import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_response.dart';
import 'package:auto_podbor_mobile/models/order_response_status.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/time_slot.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/order_card.dart';

/// Карточка заказчика считает только отклики в игре: устаревшие после
/// переноса, отказ и срыв выбрать нельзя — их нет ни в «N откликов», ни в
/// «от X ₽» (QA №11).
void main() {
  const customer = UserSummary(id: 1, name: 'Андрей С.');

  Order order(List<(OrderResponseStatus, int)> responses) => Order(
    id: 801,
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
    askingPrice: 4000,
    responses: [
      for (final (i, (status, price)) in responses.indexed)
        OrderResponse(
          id: i + 1,
          status: status,
          proposedPrice: price,
          executor: UserSummary(id: 10 + i, name: 'Исполнитель $i'),
        ),
    ],
  );

  Future<void> pump(WidgetTester tester, Order o) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: OrderCard(order: o, onTap: () {}),
      ),
    ),
  );

  testWidgets('только неактуальные — «пока нет откликов» и цена заказчика', (
    tester,
  ) async {
    await pump(
      tester,
      order([
        (OrderResponseStatus.outdated, 3000),
        (OrderResponseStatus.declined, 2500),
        (OrderResponseStatus.expired, 2000),
      ]),
    );
    expect(find.text('пока нет откликов'), findsOneWidget);
    expect(find.text('4 000 ₽'), findsOneWidget);
    expect(find.textContaining('от '), findsNothing);
  });

  testWidgets('минимум цены — только среди откликов в игре', (tester) async {
    await pump(
      tester,
      order([
        (OrderResponseStatus.pending, 3500),
        (OrderResponseStatus.outdated, 3000),
      ]),
    );
    expect(find.textContaining('1 отклик'), findsOneWidget);
    expect(find.text('от 3 500 ₽'), findsOneWidget);
  });
}
