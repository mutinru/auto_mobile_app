import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_backend.dart';
import 'package:auto_podbor_mobile/data/mock_payment_repository.dart';
import 'package:auto_podbor_mobile/models/notification_type.dart';
import 'package:auto_podbor_mobile/models/payment.dart';
import 'package:auto_podbor_mobile/screens/payments_screen.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// «Платежи и чеки» (бекенд: GET /payments, App\Receipts): чек — с сервера,
/// статус чека не считается на клиенте.
void main() {
  test('разбор: чек и его статусы', () {
    final payment = Payment.fromJson({
      'id': 7,
      'status': 'paid',
      'amount': 490,
      'refunded_amount': 490,
      'description': 'Размещение подбора Kia Rio',
      'paid_at': '2026-11-14T09:00:00+00:00',
      'receipt': {
        'status': 'cancelled',
        'url': 'https://lknpd.nalog.ru/api/v1/receipt/1/abc/print',
        'registered_at': '2026-11-14T09:00:05+00:00',
        'cancelled_at': '2026-11-15T10:00:00+00:00',
      },
    });
    expect(payment.isRefunded, isTrue);
    expect(payment.receipt?.status, ReceiptStatus.cancelled);
    expect(receiptStatusFromApi('registering'), ReceiptStatus.issuing);
    expect(receiptStatusFromApi('failed'), ReceiptStatus.issuing);
    expect(receiptStatusFromApi('новый'), ReceiptStatus.unknown);
    expect(
      notificationTypeFromApi('receipt_issued').opensPayments,
      isTrue,
    );
    expect(
      notificationTypeFromApi('receipt_cancelled'),
      NotificationType.receiptCancelled,
    );
  });

  testWidgets('списанный платёж — с чеком, удержанный — без', (tester) async {
    final backend = MockBackend();
    final vin = backend.startPayment(299, 'vin_report');
    backend.settle(vin, methodType: 'bank_card');
    final placement = backend.startPayment(490, 'selection_placement');
    backend.settle(placement, methodType: 'bank_card');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PaymentsScreen(repository: MockPaymentRepository(backend)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Готовые отчёты по VIN'), findsOneWidget);
    expect(find.text('299 ₽'), findsOneWidget);
    expect(find.text('Чек об оплате'), findsOneWidget);
    expect(find.text('Открыть'), findsOneWidget);
    // удержание чека не даёт
    expect(find.text('490 ₽'), findsOneWidget);
    expect(find.textContaining('удержано'), findsOneWidget);
  });

  testWidgets('оплат нет', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PaymentsScreen(repository: MockPaymentRepository(MockBackend())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Оплат пока не было'), findsOneWidget);
  });
}
